from io import StringIO, TextIOBase
from collections import defaultdict
import logging
import re
import numpy as np


# everything 0-based


####################################################################################
##############             IO                              #########################
####################################################################################

def load_bed(bed_path: str):
    """
    Reads a BED file and returns a dictionary of positions that are present in the file.
    bed is 0-based coordinates
    """

    # Using defaultdict(dict) for clean nested structure
    result = defaultdict(lambda: defaultdict(bool))
    if bed_path is None:
        return result
    
    with open(bed_path, 'rt') as f:   
        for line in f:
            line = line.rstrip('\n')
            if not line or line.startswith('#') or line.startswith('track ') or line.startswith('browser '):
                continue
                
            fields = line.split('\t')
            assert len(fields)>=3
            chrom = fields[0]
            start = int(fields[1])
            end   = int(fields[2])

            # BED is [start, end) → we include all positions from start inclusive to end inclusive
            for pos in range(start, end+1):
                result[chrom][pos] = True
    return result

def load_fasta(fafile):
    entries = {}
    current_header = None
    current_sequence = []
    fh=None
    if  isinstance(fafile, TextIOBase):
        fh=fafile
    else:
        fh=open(fafile,'r')
    
    for line in fh:
        line = line.rstrip()  # remove trailing \n
        
        if line.startswith('>'):
            # Save previous entry if exists
            if current_header is not None:
                seq = ''.join(current_sequence)
                entries[current_header]=seq
            
            # Start new entry; get rid of >
            current_header = line[1:]
            # split and get rid of anything after whitespace
            if re.search(r'\s', current_header):
                current_header=re.split(r'\s+', current_header)[0]
            current_sequence = []
        elif line and current_header is not None:
            # Add sequence line (skip empty lines)
            current_sequence.append(line)
    
    # Don't forget the last entry!
    if current_header is not None:
        seq = ''.join(current_sequence)
        entries[current_header]=seq
    fh.close()
    
    return entries

class Writer:

    def __init__(self,outfile):
        self.outfile=outfile
        self.file_handle=None
        self.should_close=False
        if outfile is not None:
            self.file_handle=open(outfile,"w")
            self.should_close=True
        
    def write(self,towrite:str):
        if self.file_handle is not None:
            self.file_handle.write(towrite+"\n")
        else:
            print(towrite)
    
    def __exit__(self, exc_type, exc_val, exc_tb):
            if self.should_close and self.file_handle is not None:
                self.file_handle.close()
                self.file_handle = None

class SeqEntryReader:
    """
    Simple iterator over SeqEntry file that yields one record at a time.

    
    Usage:
        for se in SeqEntry("seqentryfile.se"):
            ...
    """
    
    def __init__(self, file, need_ambcov=True):
        self.file = file
        self._file = None
        self._should_close = False
        self._need_ambcov = need_ambcov

    def __iter__(self):
        self._open_file()
        self._activeSeq = None
        self._activeLines = []
        return self

    def __next__(self):
        while True:
            line = self._file.readline()
            if not line:
                # End of file — yield last record if any
                if self._activeSeq:
                    se = SeqEntry.parse(self._activeLines, need_ambcov=self._need_ambcov)
                    self._activeSeq = None
                    self._activeLines = []
                    return se
                raise StopIteration

            line = line.rstrip('\n\r')
            line=line.strip()
            seqName=line.split("\t")[0]
            

            # first record; initialize
            if self._activeSeq is None:
                self._activeSeq=seqName
                self._activeLines=[line]
            # new record; safe and start new one
            elif seqName!=self._activeSeq:
                # New record starts
                # Yield previous record
                se = SeqEntry.parse(self._activeLines, need_ambcov=self._need_ambcov)
                self._activeSeq=seqName
                self._activeLines = [line]
                return se
            elif line:  # skip empty lines
                self._activeLines.append(line)

    def _open_file(self):
        if self._file is not None:
            return
        if hasattr(self.file, 'readline'):
            # already a file object
            self._file = self.file
            self._should_close = False
        else:
            # assume it's a path
            path = self.file
            if path.endswith(('.gz', '.gzip')):
                import gzip
                self._file = gzip.open(path, 'rt')
            else:
                self._file = open(path, 'r')
            self._should_close = True

    

    def close(self):
        if self._should_close and self._file is not None:
            self._file.close()
            self._file = None

    def __enter__(self):
        self._open_file()
        return self

    def __exit__(self, exc_type, exc_val, exc_tb):
        self.close()


def isssnp(refc,hash,cov,minc,minfreq):
    # refc = A
    # hash =
    if cov==0:
        return False
    if 'A'!= refc:
        ac=hash['A']
        af=float(ac)/float(cov)
        if ac>=minc and af>=minfreq:
            return True
    if 'T' != refc:
        tc=hash['T']
        tf=float(tc)/float(cov)
        if tc>=minc and tf >=minfreq:
            return True
    if 'C'!= refc:
        cc=hash['C']
        cf=float(cc)/float(cov)
        if cc>=minc and cf>=minfreq:
            return True
    if 'G' != refc:
        gc=hash['G']
        gf=float(gc)/float(cov)
        if gc>=minc and gf >=minfreq:
            return True
    return False


####################################################################################
##############             Normalization.                  #########################
####################################################################################


class NormFactor:

    def _getCovTriplet(cov:list,qlen:int):
        if qlen==0:
            mcov=float(sum(cov))/float(len(cov))
            return [mcov,None,None]
        
        cov = sorted(cov)  # copy — cov may be a view into se.cov; must not sort in place
        first=  cov[:qlen]
        middle=  cov[qlen:-qlen]
        last=  cov[-qlen:]
        mfirst=float(sum(first))/float(len(first))
        mmiddle=float(sum(middle))/float(len(middle))
        mlast=float(sum(last))/float(len(last))
        return [mmiddle,mfirst,mlast]



    @classmethod
    def getCovStat(cls, se, minDistance:int, quantile:int):
        assert quantile<50 and quantile>=0
        assert minDistance >=0
        cov=se.cov
        ambcov=se.ambcov
        if minDistance>0:
                cov=cov[minDistance:-minDistance]
                ambcov=ambcov[minDistance:-minDistance]
        assert len(cov)==len(ambcov)
        if len(cov)==0:
            return [None,]*6
        qfrac=float(quantile)/100.0
        qlen=int(len(cov)*qfrac)
        covtrip=NormFactor._getCovTriplet(cov,qlen)
        ambcovtrip=NormFactor._getCovTriplet(ambcov,qlen)
        toret=[]
        toret.extend(covtrip)
        toret.extend(ambcovtrip)
        return toret


    @classmethod
    def getNormalizationFactor(cls, filename:str, scg_suffix:str, min_end_distance: int, quanitle:int):
        # compute the normalization factor from a seq-entry file (seq overview file so-file)
        scgs=[]
        for se in SeqEntryReader(filename):
            if se.seqname.endswith(scg_suffix):
                scgs.append(se)

        if len(scgs)==0:
            raise Exception("Cannot normalize without single copy genes")
        normfactor=NormFactor.computeNormFactorForSe(scgs,min_end_distance,quanitle)
        return normfactor

    @classmethod
    def computeNormFactorForSe(cls, seqEntries: list, minDistance:int,quantile:int):
        assert quantile<50 and quantile>=0
        assert minDistance >=0
        per_scg_medians=[]
        for se in seqEntries:
            if se.cov is None or len(se.cov) == 0:
                continue
            per_scg_medians.append(float(np.median(se.cov)))

        if len(per_scg_medians)==0:
            raise Exception("Unable to normalize; no valid coverage for a single copy gene")
        # mean of per-SCG medians: each gene contributes equally regardless of length
        return sum(per_scg_medians)/len(per_scg_medians)





####################################################################################
##############             SeqEntry + Indel SNP            #########################
####################################################################################


class Indel:
    @classmethod
    def parse(cls,e):
        if len(e)!=5:
            raise Exception(f"Cannot parse Indel {e}")
        ref,type,pos,length,count=e[0],e[1],int(e[2]),int(e[3]),float(e[4])
        return Indel(ref,type,pos,length,count)
 
    def __init__(self,ref:str,type:str,pos:int,length:int,count):
        self.ref=ref
        self.type=type # ins or del
        self.pos=pos
        self.length=length
        self.count=count
    
    def __str__(self):
        # ref, type, pos, length, count
        tp=[self.ref, self.type, f"{self.pos}",f"{self.length}",f"{self.count:.2f}"]
        tp="\t".join(tp)
        return tp
    
    def normalize(self, normfactor:float):
        ni=Indel(self.ref,self.type,self.pos,self.length,float(self.count)/normfactor)
        return ni


class SNP:
    @classmethod
    def parse(cls,e):
        if len(e)!=8:
            raise Exception(f"Cannot parse SNP {e}")
        ref,type,pos,refc,ac,tc,cc,gc =e[0],e[1],int(e[2]),e[3],float(e[4]),float(e[5]),float(e[6]),float(e[7])
        return SNP(ref,pos,refc,ac,tc,cc,gc)


    def __init__(self,ref:str,pos:int,refc:str,ac,tc,cc,gc):
        self.ref=ref
        self.pos=pos
        self.refc=refc
        self.ac=ac
        self.tc=tc
        self.gc=gc
        self.cc=cc
    
    def __str__(self):
        # ref, 'snp', pos, refc, ac tc cc gc
        tp=[self.ref, "snp",  f"{self.pos}", self.refc,f"{self.ac:.2f}",f"{self.tc:.2f}",f"{self.cc:.2f}",f"{self.gc:.2f}"] 
        tp="\t".join(tp)
        return tp
    
    def normalize(self,normFactor:float):
        acn=float(self.ac)/normFactor
        tcn=float(self.tc)/normFactor
        ccn=float(self.cc)/normFactor
        gcn=float(self.gc)/normFactor
        ns=SNP(self.ref,self.pos,self.refc,acn,tcn,ccn,gcn)
        return ns
    




class SeqEntry:

    @classmethod
    def parse(cls,lines,need_ambcov=True):
        activeName=None
        covar=None
        ambcovar=None
        ambcov_seen=False
        snplist=[]
        indellist=[]

        for l in lines:
            tmp=l.split("\t")
            sn=tmp[0]
            if activeName is None:
                activeName=sn
            assert sn == activeName
            feature=tmp[1]
            if feature=="ins" or feature == "del":
                indel=Indel.parse(tmp)
                indellist.append(indel)
            elif feature == "snp":
                snp=SNP.parse(tmp)
                snplist.append(snp)
            elif feature =="cov":
                if covar is not None:
                    raise Exception(f"two coverage arrays for sequence {sn}")
                covar = np.fromstring(tmp[2], dtype=np.float64, sep=" ")
            elif feature =="ambcov":
                if ambcov_seen:
                    raise Exception(f"two amb coverage arrays for sequence {sn}")
                ambcov_seen = True
                # skip the float conversion entirely when the caller doesn't need it —
                # this array is as large as cov and often unused (e.g. SNP-only stats)
                if need_ambcov:
                    ambcovar = np.fromstring(tmp[2], dtype=np.float64, sep=" ")
            else:
                raise Exception(f"Unknown feature {feature}")
        if covar is None:
            raise Exception(f"No coverage for {activeName}")
        if not ambcov_seen:
            raise Exception(f"No ambiguous coverage for {activeName}")
        return SeqEntry(activeName,covar,ambcovar,snplist,indellist)
    
    def __init__(self,seqname:str,cov,ambcov,snplist,indellist):
        self.seqname=seqname
        self.cov=cov
        self.ambcov=ambcov
        self.snplist=snplist
        self.indellist=indellist
    
    def __str__(self):
        # cov
        tmp=" ".join([f"{i:.2f}" for i in self.cov])
        tpcov="\t".join([self.seqname,"cov",tmp])
        #ambcov
        tmp=" ".join([f"{i:.2f}"  for i in self.ambcov])
        tpambcov="\t".join([self.seqname,"ambcov",tmp])
        tp=[tpcov,tpambcov]
        for s in self.snplist:
            tp.append(str(s))
        for id in self.indellist:
            tp.append(str(id))
        topr="\n".join(tp)
        return topr
    
    def normalize(self,normfactor:float):
        cov=[float(i)/normfactor for i in self.cov]
        ambcov=[float(i)/normfactor for i in self.ambcov]
        snplist=[]
        for s in self.snplist:
            snplist.append(s.normalize(normfactor))
        indellist=[]
        for i in self.indellist:
            indellist.append(i.normalize(normfactor))
        return SeqEntry(self.seqname,cov,ambcov,snplist,indellist)


####################################################################################
##############             Seqbuilder.                     #########################
####################################################################################


class SeqBuilder:
    def __init__(self,seq:str,seqname:str,minmapq:int):
        self.seq=seq
        self.seqlen=len(seq)
        self.seqname=seqname
        self.snpar=[{'A':0,'T':0,'C':0,'G':0} for i in list(seq)]
        self.covar=[0 for i in list(seq)]
        self.ambcovar=[0 for i in list(seq)]
        self.inscol=[]
        self.delcol=[]
        self.minmapq=minmapq

    def __parse_cigar(self,cigar: str):
        """Parse CIGAR string into list of (op, length) tuples."""
        ops = []
        i = 0
        num = ""
        while i < len(cigar):
            if cigar[i].isdigit():
                num += cigar[i]
            else:
                if num:
                    ops.append((cigar[i], int(num)))
                    num = ""
            i += 1
        return ops
    
    def __add_coverage(self,refpos: int,ops,mapq:int):
        rpos=refpos # 0-based everything
        qpos=0
        ### ref     ATTTAAACCCC---AAAA
        ### que.    ATTT---CCCCTTTAAAA
        ###             D      I
        for op, length in ops:
            if op in ('H', 'S'):  # Hard/soft clip: consumes query only; does not add to coverage
                qpos += length
            elif op == 'I':  # Insertion: consumes query only; does not add to coverage
                qpos += length
            elif op in('D','N'):  # Deletion: consumes reference only; does add to coverage
                for i in range(length):
                    p=rpos+i
                    if p>=self.seqlen:
                        break
                    self.covar[p]+=0 # should i add to coverage -> at moment no
                    if mapq<self.minmapq:
                        self.ambcovar[p]+=0 # should i add to coverage -> at moment no
                rpos += length
            elif op in ('M', '=', 'X'):  # Match/mismatch: consumes both; adds coverage
                for i in range(length):
                    p=rpos+i
                    if p>=self.seqlen:
                        break
                    self.covar[p]+=1
                    if mapq<self.minmapq:
                        self.ambcovar[p]+=1
                rpos += length
                qpos += length

    def __add_indels(self,refpos:int,ops):
        rpos=refpos # 0-based everything
        qpos=0
        ### ref     ATTTAAACCCC---AAAA
        ### que.    ATTT---CCCCTTTAAAA
        ###             D      I
        for op, length in ops:
            if op in ('H', 'S'):  # Hard/soft clip: consumes query only; does not add to coverage
                qpos += length
            elif op == 'I':  # Insertion: consumes query only; does not add to coverage
                self.inscol.append((rpos,length))
                qpos += length
            elif op in('D','N'):  # Deletion: consumes reference only; does add to coverage
                self.delcol.append((rpos,length))
                rpos += length
            elif op in ('M', '=', 'X'):  # Match/mismatch: consumes both
                rpos += length
                qpos += length

    def __add_snps(self,refpos:int,ops,seq:str):
        ### ref     ATTTAAACCCC---AAAA
        ### que.    ATTT---CCCCTTTAAAA
        rpos=refpos # 0-based everything
        qpos=0
        for op, length in ops:
            if op in ('H', 'S'):  # Hard/soft clip: consumes query only
                qpos += length
            elif op == 'I':  # Insertion: consumes query only
                qpos += length
            elif op in('D','N'):  # Deletion: consumes reference only
                rpos += length
            elif op in ('M', '=', 'X'):  # Match/mismatch: consumes both
                for i in range(length):
                    base = seq[qpos + i]
                    if base in 'ATCG':
                        p=rpos+i
                        if p>=self.seqlen:
                            break
                        self.snpar[p][base]+=1
                rpos += length
                qpos += length
            # Ignore N (skipped reference), P (padding) if present

    
    def add_read(self,refpos:int,cigar:str,mapq:int,seq:str):

        ops=self.__parse_cigar(cigar)
        self.__add_coverage(refpos,ops,mapq) # increase coverage; only cigar and mapquality considered
        self.__add_indels(refpos,ops)        # add indels; only cigar considered; mapq ignored
        self.__add_snps(refpos,ops,seq)      # add snps; only cigar considered; mapq ignored
    
    def toSeqEntry(self,mcsnp,mfsnp,mcindel,mfindel):
        snplist=[]
        for i,snp in enumerate(self.snpar):
            refc=self.seq[i]
            cov=self.covar[i]
            if isssnp(refc,snp,cov,mcsnp,mfsnp):
                snpentry=SNP(self.seqname,i,refc,snp['A'],snp['T'],snp['C'],snp['G']) # 0-based snp position
                snplist.append(snpentry)
        
        indellist=[]
        # INSERTIONS
        tmp=defaultdict(int)
        for ins in self.inscol:
            tmp[ins]+=1
        for ins,count in tmp.items():
            pos=ins[0] # -1 # position in ins is 0-based everything
            cov=self.covar[pos-1]
            if cov == 0:
                continue
            insfreq=float(count)/float(cov)
            if count>=mcindel and insfreq>=mfindel:
                id=Indel(self.seqname,"ins",ins[0],ins[1],count)
                indellist.append(id)

        # DELETIONS; kept separate on purpose; in case I want to treat them differentially later
        tmp=defaultdict(int)
        for de in self.delcol:
            tmp[de]+=1
        for de,count in tmp.items():
            pos=de[0] # -1 # 0-based everything
            cov=self.covar[pos-1]
            if cov == 0:
                continue        
            defreq=float(count)/float(cov)
            if count>=mcindel and defreq>=mfindel:
                id=Indel(self.seqname,"del",de[0],de[1],count)
                indellist.append(id)

        se=SeqEntry(self.seqname,self.covar,self.ambcovar,snplist,indellist)
        return se

        





####################################################################################
##############             Plotable formater               #########################
####################################################################################
####  ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ########
####  ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ########
###### 1-based output for R.    1-based output for R.    1-based output for R ######
####  ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ATTENTION ########
###### 1-based output for R.    1-based output for R.    1-based output for R ######

class PlotableFormater:

    ####################################################################################
    #### offset switching from 0-based to 1-based
    offset=1
    
    @classmethod
    def prepareCoveragForPrint(cls, seqname: str, cov: list, sampleid: str, covtype: str, bin_size: int = 1):
        tmp = []
        n = len(cov)
        if bin_size <= 1:
            for i, c in enumerate(cov):
                tmp.append([seqname, sampleid, covtype, str(i + cls.offset), str(c)])
        else:
            for start in range(0, n, bin_size):
                end = min(start + bin_size, n)
                chunk = cov[start:end]
                avg = sum(chunk) / len(chunk)
                mid_pos = start + (end - start) // 2 + cls.offset
                tmp.append([seqname, sampleid, covtype, str(mid_pos), str(avg)])

        if not tmp:
            return tmp

        # R-polygon necessity
        first, last = tmp[0], tmp[-1]
        tmp.insert(0, [first[0], first[1], first[2], first[3], "0.0"])
        tmp.append([last[0], last[1], last[2], last[3], "0.0"])
        return tmp
    
    @classmethod
    def prepareSNPForPrint(cls, se:SeqEntry, sampleid:str,tomask):
        toret=[]
        for s in se.snplist:
            if s.pos in tomask:
                continue
            # seqname, sampleid, snp, pos, refc, ac, tc, cc, gc
            # SNP(ref,pos,refc,ac,tc,cc,gc)
            a={"A":s.ac,"T":s.tc,"C":s.cc,"G":s.gc}
            for base,count in a.items():
                if count ==0 or base==s.refc:
                    continue
                tmp=[se.seqname,sampleid,"snp",str(s.pos+PlotableFormater.offset), s.refc,base,str(count)]
                toret.append(tmp)
        return toret
    
    @classmethod
    def prepareIndelForPrint(cls, se:SeqEntry, sampleid:str,tomask):
        toret=[]
        for i in se.indellist:
            if i.type=="ins":
                # 123456---789012
                # 012345---678901 0-based = (6,3) insertions
                # AAATTT---CCCGGG  
                #    TTTAAACCC
                if i.pos in tomask:
                    continue
                # seqname, sampleid, del, pos, length, count
                # intentionally not using PlotableFormater.offset since I think first coordindate of insertion is better 
                tmp=[se.seqname,sampleid,"ins",str(i.pos),str(i.length),str(i.count)] 
                toret.append(tmp)
                # ref:str,type:str,pos:int,length:int,count

            elif i.type=="del":
                # 123456890123
                # 012345678901.  0-based = (6,3) deletion
                # AAATTTCCCGGG
                #    TTT---AAA
                # seqname, sampleid, ins, startpos, endpos, startcov,endcov, count
 
                startpos=i.pos # eg 6
                endpos=startpos+i.length # eg 9 = 6+3
                if startpos in tomask or endpos in tomask:
                    continue
                startcov=float(se.cov[startpos-1]) # startcov at 5 = 6-1
                endcov=float(se.cov[endpos])   # endcov at 9
                
                # note startpos does not get PlottableFormat.offset on purpose! endpos needs offset
                # desired startpos in 1-based = 6; endpos = 10
                tmp=[se.seqname,sampleid,"del",str(startpos),str(endpos+PlotableFormater.offset),str(startcov),str(endcov),str(i.count)]
                toret.append(tmp)

            else:
                raise Exception(f"invalid type{i.type}")
        return toret

    @classmethod
    def prepareForPrint(cls, se: SeqEntry, sampleid: str, tomask, ymax, bin_size: int = 1):
        # get local masking
        localmask=tomask[se.seqname] # bed is 0-based
        # coverages and mask according to user specifications
        cov=se.cov
        ambcov=se.ambcov
        mcov=[0]*len(cov)

        for i in range(0,len(cov)):
            c=cov[i]
            # mask coverage if either in localmaks or coverage exceeds ymax
            if (i in localmask):
                ambcov[i]=0
                mcov[i]=cov[i]
                cov[i]=0
            elif ymax is not None and c>ymax:
                ambcov[i]=0
                mcov[i]=ymax
                cov[i]=0
                localmask[i]=True

        lines=[]
        covt=PlotableFormater.prepareCoveragForPrint(se.seqname, cov, sampleid, "cov", bin_size)
        ambcovt=PlotableFormater.prepareCoveragForPrint(se.seqname, ambcov, sampleid, "ambcov", bin_size)
        mcovt=PlotableFormater.prepareCoveragForPrint(se.seqname, mcov, sampleid, "mcov", bin_size)
        lines.extend(covt)
        lines.extend(ambcovt)
        lines.extend(mcovt)

        snps=PlotableFormater.prepareSNPForPrint(se,sampleid,localmask)
        lines.extend(snps)
        indels=PlotableFormater.prepareIndelForPrint(se,sampleid,localmask)
        lines.extend(indels)

        return lines

####################################################################################
##############             TESTS                           #########################
####################################################################################


def test_computeNormalization():
    # todo add tests for quantiles
    ses=[SeqEntry("t",[10,]*10,[],[],[]),SeqEntry("t",[2,]*10,[],[],[])]
    nf=NormFactor.computeNormFactorForSe(ses,0,0)
    assert nf==6, "test1"

    # median-of-medians: SCG1 median=10, SCG2 median=2, median-of-[10,2]=(10+2)/2=6
    ses=[SeqEntry("t",[1,10,10,10,10,10,1],[],[],[]),SeqEntry("t",[1,2,2,2,2,2,1],[],[],[])]
    nf=NormFactor.computeNormFactorForSe(ses,0,0)
    assert nf==6, "test2"

    print("Quick test computation of normalization factor passed ✓")


def test_covstat():
    se=SeqEntry("t",[0,2,2,2,2,2,1,2,3,2,2,0],[99,5,5,5,6,4,5,5,5,5,5,99],[],[])
    cs=NormFactor.getCovStat(se,1,10)

    assert cs[0]==2
    assert cs[1]==1
    assert cs[2]==3
    assert cs[3]==5
    assert cs[4]==4
    assert cs[5]==6
    print("Quick test computations of coverage statistic passed ✓")

def test_covstat_does_not_mutate_se_cov():
    # se.cov/ambcov are numpy arrays once loaded via SeqEntry.parse; slicing them
    # yields a view, so NormFactor._getCovTriplet must sort a copy, not the view,
    # or it silently reorders se.cov in place.
    cov = np.array([0,2,2,2,2,2,1,2,3,2,2,0], dtype=np.float64)
    ambcov = np.array([99,5,5,5,6,4,5,5,5,5,5,99], dtype=np.float64)
    cov_before = cov.copy()
    ambcov_before = ambcov.copy()
    se = SeqEntry("t", cov, ambcov, [], [])
    NormFactor.getCovStat(se, 1, 10)
    assert (se.cov == cov_before).all()
    assert (se.ambcov == ambcov_before).all()
    print("Quick test that getCovStat does not mutate se.cov/ambcov PASSED ✓")

def test_seqentryreader_need_ambcov_false_skips_ambcov():
    se_in = SeqEntry("chr1", [1.0, 2.0, 3.0], [9.0, 9.0, 9.0], [], [])
    so_text = str(se_in) + "\n"

    reader = SeqEntryReader(StringIO(so_text), need_ambcov=False)
    entries = list(reader)

    assert len(entries) == 1
    se = entries[0]
    assert list(se.cov) == [1.0, 2.0, 3.0]
    assert se.ambcov is None
    print("Quick test that need_ambcov=False skips ambcov parsing PASSED ✓")

def test_normalize():
    s=SNP("chr1",1,"A",5,6,7,1)
    sn=s.normalize(2.0)
    assert sn.ref=="chr1"
    assert sn.pos== 1
    assert sn.refc=="A"
    assert sn.ac==2.5
    assert sn.tc==3
    assert sn.cc==3.5
    assert sn.gc==0.5

    print("Quick test of SNP normalization PASSED ✓")
    id=Indel("chr2", "ins",5,2,11)
    idn=id.normalize(2.0)
    assert idn.ref == "chr2"
    assert idn.type=="ins"
    assert idn.pos==5
    assert idn.count==5.5
    assert idn.length==2
    print("Quick test of Insertion normalization PASSED ✓")
    deli=Indel("chr3", "del",5,2,20)
    de=deli.normalize(5.0)
    assert de.ref == "chr3"
    assert de.type=="del"
    assert de.pos==5
    assert de.count==4
    assert de.length==2
    print("Quick test of Deletion normalization PASSED ✓")

    id=Indel("chr2", "ins",5,2,11)
    deli=Indel("chr3", "del",5,2,20)
    s=SNP("chr1",1,"A",5,6,7,1)
    se=SeqEntry("te1",[5,6,6,4,2],[2,3,4,6,1],[s],[id,deli])
    sn=se.normalize(2)
    assert sn.cov[0]==2.5
    assert sn.cov[1]==3
    assert sn.cov[4]==1
    assert sn.ambcov[0]==1
    assert sn.ambcov[1]==1.5
    assert sn.ambcov[4]==0.5
    assert sn.ambcov[3]==3
    assert sn.snplist[0].ac==2.5
    assert sn.indellist[0].count==5.5
    assert sn.indellist[1].count==10
    print("Quick test of SeqEntry normalization PASSED ✓")


def test_getSNP():
    # toSeqEntry(self,mcsnp,mfsnp,mcindel,mfindel):
    sb=SeqBuilder("AAATTTCCCGGG","hans",5)
    sb.add_read(0,"3M",5,"AAT")
    sb.add_read(0,"3M",5,"AAT")
    sb.add_read(0,"3M",5,"TAT")
    sb.add_read(0,"3M",5,"TCT")
    se=sb.toSeqEntry(2,0.1,2,0.1)

    assert len(se.snplist)==2
    assert se.snplist[0].pos==0
    assert se.snplist[0].ac==2
    assert se.snplist[0].tc==2
    assert se.snplist[1].pos==2
    assert se.snplist[1].ac==0
    assert se.snplist[1].tc==4
    b=0
    print("Quick test of SNP calling PASSED ✓")


def test_getInsertion():
    # toSeqEntry(self,mcsnp,mfsnp,mcindel,mfindel):
    sb=SeqBuilder("AAATTTCCCGGG","hans",5)
    # 123456---789012
    # 012345---678901 0-based = (6,3) insertions
    # AAATTT---CCCGGG  
    #    TTTAAACCC
    sb.add_read(3,"3M3I3M",5,"TTTAAACCC")
    sb.add_read(3,"3M3I3M",5,"TTTAAACCC")
    se=sb.toSeqEntry(2,0.1,2,0.1)

    assert len(se.indellist)==1
    assert se.indellist[0].pos==6
    assert se.indellist[0].length==3
    assert se.indellist[0].count==2
    assert se.indellist[0].type=="ins"
    b=0
    print("Quick test of Insertion calling PASSED ✓")


def test_getDeletion():
    # toSeqEntry(self,mcsnp,mfsnp,mcindel,mfindel):
    sb=SeqBuilder("AAATTTCCCGGG","hans",5)
    # 123456890123
    # 012345678901.  0-based = (6,3) deletion
    # AAATTTCCCGGG
    #    TTT---AAA
    sb.add_read(3,"3M3D3M",5,"TTTAAA")
    sb.add_read(2,"4M3D3M",5,"TTTTAAA")
    sb.add_read(3,"3M3D3M",5,"TTTAAC")
    se=sb.toSeqEntry(2,0.1,2,0.1)

    assert len(se.indellist)==1
    assert se.indellist[0].pos==6
    assert se.indellist[0].length==3
    assert se.indellist[0].count==3
    assert se.indellist[0].type=="del"
    print("Quick test of Deletion calling PASSED ✓")


def test_Seq_Builder_add():
    # 012345678901
    # AAATTTCCCGGG
    # AAA
    # TTT
    sb=SeqBuilder("AAATTTCCCGGG","hans",5)
    sb.add_read(0,"3M",4,"ACC")
    sb.add_read(0,"3M",5,"TGG")

    assert sb.covar[0]==2
    assert sb.ambcovar[0]==1
    assert sb.covar[1]==2
    assert sb.ambcovar[1]==1
    assert sb.covar[2]==2
    assert sb.ambcovar[2]==1
    assert sb.covar[3]==0
    assert sb.ambcovar[3]==0
    assert sb.snpar[0]['A']==1
    assert sb.snpar[0]['T']==1
    
    # 123456---789012
    # 012345---678901
    # AAATTT---CCCGGG
    #    TTTAAACCC
    sb.add_read(3,"3=3I3X",5,"TTTAAACCC")
    assert sb.covar[3]==1
    assert sb.covar[4]==1
    assert sb.covar[5]==1
    assert sb.covar[6]==1
    assert sb.covar[7]==1
    assert sb.covar[8]==1
    assert sb.covar[9]==0
    assert sb.snpar[3]['T']==1
    assert sb.snpar[6]['A']==0
    assert sb.snpar[6]['C']==1
    assert sb.inscol[0]==(6,3),  f"got {sb.inscol[0]}"

    # 123456---789012
    # 012345---678901
    # AAATTTCCCGGG
    #    TTT---AAA
    sb.add_read(3,"3M3D3M",5,"TTTAAA")
    assert sb.covar[3]==2
    assert sb.covar[4]==2
    assert sb.covar[5]==2
    assert sb.covar[6]==1
    assert sb.covar[7]==1
    assert sb.covar[8]==1
    assert sb.covar[9]==1
    assert sb.covar[10]==1
    assert sb.covar[11]==1
    assert sb.delcol[0]==(6,3), f"got {sb.delcol[0]}"

    sb.add_read(11,"3M",5,"TTT")

    print("Quick test of SeqBuilder add PASSED ✓")


def test_Seq_Builder_init():
    sb=SeqBuilder("AAATTTCCCGGG","hans",5)
    assert sb.seq == "AAATTTCCCGGG",           f"sequence"
    assert sb.seqname == "hans",            f"seqname"
    assert sb.minmapq ==5,                  f"minmapq"
    assert len(sb.covar) == 12,             f"length of covar"
    assert len(sb.ambcovar) == 12,           f"length of ambcovar"
    assert len(sb.snpar) == 12,           f"length of ambcovar"
    assert len(sb.inscol) == 0,           f"length of ambcovar"
    assert len(sb.delcol) == 0,           f"length of ambcovar"
    print("Quick test of SeqBuilder __init__ PASSED ✓")

def test_fasta_loader():
    from io import StringIO
    
    test_content = """>seq1 some description
ACGTACGT
GCTA
>seq2
NNNNNNNNNN
>seq3 empty sequence

>seq4
ATGCATGCATGC
"""

    result = load_fasta(StringIO(test_content))
    
    expected = {
        "seq1": "ACGTACGTGCTA",
        "seq2": "NNNNNNNNNN",
        "seq3": "",
        "seq4": "ATGCATGCATGC"
    }
    
    assert len(result) == 4,           f"Expected 4 sequences, got {len(result)}"
    assert "seq3" in result,           "Missing empty sequence entry"
    assert result["seq3"] == "",       "Empty sequence should be empty string"
    assert result == expected,         "Dictionary content doesn't match expected"
    
    print("Quick test of fasta_loader PASSED ✓")

def test_convert_to_portable():
    # (self,seqname:str,cov,ambcov,snplist,indellist):
    se=SeqEntry("tr1",[],[],[],[])
    se.snplist.append(SNP("t",100,"A",2,3,4,0))
    sl=PlotableFormater.prepareSNPForPrint(se,"tamtam",{})

    assert len(sl)==2
    assert sl[0][3]=="101" # conversion 100->101 R is 1-based
    assert sl[0][6]=="3"
    assert sl[1][3]=="101" # conversion 100->101 R is 1-based
    assert sl[1][6]=="4"  


    se=SeqEntry("tr1",[],[],[],[])
    se.indellist.append(Indel("t","ins",200,3,10))
    ins = PlotableFormater.prepareIndelForPrint(se,"tamtam",{})
    assert len(ins)==1
    assert ins[0][3]=="200" # conversion of 200 -> 200 (position is now one position before insertion; instead of 1 position after insertion)
    
    # (self,seqname:str,cov,ambcov,snplist,indellist):
    se=SeqEntry("tr1",[i for i in range(1000,1400)],[],[],[])
    se.indellist.append(Indel("t","del",300,10,20))
    dele = PlotableFormater.prepareIndelForPrint(se,"tamtam",{})
    assert len(dele)==1
    assert dele[0][3]=="300" # conversion of 300 -> 300 # i want first coordinate before deletion 1-based
    assert dele[0][4]=="311" # conversion of 310 -> 311  # i want frst coordinate after deletion 1-based
    

    cov=PlotableFormater.prepareCoveragForPrint("hans",[20,30],"sepp","cov")
    assert len(cov)==4 
    assert cov[0][3]=="1"
    assert cov[3][3]=="2"

    print("Test convert to portable PASSED ✓")

def test_filter_portable():
    # (self,seqname:str,cov,ambcov,snplist,indellist):
    se=SeqEntry("tr1",[],[],[],[])
    se.snplist.append(SNP("t",11,"A",2,3,0,0))
    se.snplist.append(SNP("t",12,"A",2,3,0,0))
    se.snplist.append(SNP("t",13,"A",2,3,0,0))
    sl=PlotableFormater.prepareSNPForPrint(se,"tamtam",{12:True})

    b=0
    assert len(sl)==2
    assert sl[0][3]=="12" # 11 +1 (remember conversion from 0-based to 1-based)
    assert sl[1][3]=="14" # 13+1 
    # hence 12+1 should be missing; check

    se=SeqEntry("tr1",[],[],[],[])
    se.indellist.append(Indel("t","ins",111,3,10))
    se.indellist.append(Indel("t","ins",112,3,10))
    se.indellist.append(Indel("t","ins",113,3,10))
    ins = PlotableFormater.prepareIndelForPrint(se,"tamtam",{112:True})
    assert len(ins)==2
    assert ins[0][3]=="111" 
    assert ins[1][3]=="113" 
    print("Test filter portable PASSED ✓")
    

if __name__ == "__main__":
    test_fasta_loader()
    test_Seq_Builder_init()
    test_Seq_Builder_add()
    test_normalize()
    test_computeNormalization()
    test_covstat()
    test_getSNP()
    test_getInsertion()
    test_getDeletion()
    test_convert_to_portable()
    test_filter_portable()