FROM ubuntu

LABEL authors="zhaoqi@sysucc.org.cn,sun_yu@mail.nankai.edu.cn" \
	description="Docker image containing all requirements for LncPipe"
	
# Update OS
# DEBIAN_FRONTEND=noninteractive is for relieving the dependence of readline perl library by prohibiting interactive frontend
# build-essential is for HTSeq building
# libbz2-dev is for building HTSlib
# default-jre is for NextFlow (run groovy)
# gcc and g++ is for compiling CPAT, PLEK as well as some R packages
# gfortran is for compiling R package hexbin (required by plotly)
# make is for executing makefiles for several tools
# Cython provides C header files like Python.h for CPAT compiling
# DO NOT use pip for installing Cython, which will cause missing .h files
# zlib1g-dev is for CPAT compiling dependency
# liblzma-dev is for HTSeq building
# libncurses5-dev for samtools (may be used later)
# libssl-dev is for R package openssl
# libxml2-dev is for R package XML, which is needed by DESeq2
# libcurl4-openssl-dev is for R package curl
# perl brings us FindBin module, which is required by FastQC
# ca-certificates is required by aria2
RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get -qq update && \
	apt-get -qq install -y --no-install-recommends \
	build-essential \
	libbz2-dev \
	default-jre \
	unzip \
	pbzip2 \
	pigz \
	aria2 \
	gcc \
	g++ \
	gfortran \
	make \
	python-dev \
	cython \
	zlib1g-dev \
	liblzma-dev \
	libssl-dev \
	libxml2-dev \
	libcurl4-openssl-dev \
	perl \
	ca-certificates
	
# Install latest pip WITHOUT wheel while with setuptools
# DO NOT use apt-get python-pip in ubuntu for preventing from complicated related tools and libraries
# Setuptools is required by CPAT during its installation
RUN aria2c https://bootstrap.pypa.io/get-pip.py -q -o /opt/get-pip.py && \
	python /opt/get-pip.py --no-wheel && \
	rm /opt/get-pip.py

# Install required python packages	
RUN pip install numpy matplotlib pysam htseq
	
# Install nextflow
RUN aria2c https://github.com/nextflow-io/nextflow/releases/download/v0.25.6/nextflow -q -o /opt/nextflow && \
	chmod 777 /opt/nextflow && \
	ln -s /opt/nextflow /usr/local/bin
	
# Install STAR
RUN aria2c https://raw.githubusercontent.com/alexdobin/STAR/master/bin/Linux_x86_64/STAR -q -o /opt/STAR && \
	chmod 777 /opt/STAR && \
	ln -s /opt/STAR /usr/local/bin

# Install cufflinks	
RUN aria2c https://github.com/bioinformatist/cufflinks/releases/download/v2.2.1/cufflinks-2.2.1.Linux_x86_64.tar.gz -q -o /opt/cufflinks-2.2.1.Linux_x86_64.tar.gz && \
	tar xf /opt/cufflinks-2.2.1.Linux_x86_64.tar.gz --use-compress-prog=pigz -C /opt/ && \
	rm /opt/cufflinks-2.2.1.Linux_x86_64/README && \
	ln -s /opt/cufflinks-2.2.1.Linux_x86_64/* /usr/local/bin/ && \
	rm /opt/cufflinks-2.2.1.Linux_x86_64.tar.gz
	
# Install PLEK
# Remove documents, demo files, source files, object files and R scripts
# dos2unix in perl one-liner: remove BOM head and deal with \r problem
RUN aria2c https://excellmedia.dl.sourceforge.net/project/plek/PLEK.1.2.tar.gz -q -o /opt/PLEK.1.2.tar.gz && \
	tar xf /opt/PLEK.1.2.tar.gz --use-compress-prog=pigz -C /opt/ && \
	cd /opt/PLEK.1.2/ && \
	python PLEK_setup.py || : && \
	rm *.pdf *.txt *.h *.c *.fa *.cpp *.o *.R *.doc PLEK_setup.py && \
	chmod 777 * && \
	perl -CD -pi -e'tr/\x{feff}//d && s/[\r\n]+/\n/' *.py && \
	ln -s /opt/PLEK.1.2/PLEK* /usr/local/bin/ && \
	ln -s /opt/PLEK.1.2/svm* /usr/local/bin/ && \
	rm /opt/PLEK.1.2.tar.gz

# Use bash instead for shopt only works with bash
SHELL ["/bin/bash", "-c"]

# Install CNCI
# Enable the extglob shell option
# Parentheses and the pipe symbol should be escaped
RUN aria2c https://codeload.github.com/www-bioinfo-org/CNCI/zip/master -q -o /opt/CNCI-master.zip && \
	unzip -qq /opt/CNCI-master.zip -d /opt/ && \
	rm /opt/CNCI-master.zip && \
	unzip -qq /opt/CNCI-master/libsvm-3.0.zip -d /opt/CNCI-master/ && \
	rm /opt/CNCI-master/libsvm-3.0.zip && \
	cd /opt/CNCI-master/libsvm-3.0 && \
	make > /dev/null 2>&1 && \
	shopt -s extglob && \
	rm -rfv !\("svm-predict"\|"svm-scale"\) && \
	cd .. && \
	rm draw_class_pie.R LICENSE README.md && \
	chmod -R 777 * && \
	ln -s /opt/CNCI-master/*.py /usr/local/bin/

# Install CPAT
# DO NOT use absolute path when setup, and changing directory is necessary. Python interpreter will check current directory for dependencies
# Remove line 21 from setup.py: distribute_setup::use_setuptools() for: https://stackoverflow.com/questions/46967488/getting-error-403-while-installing-package-with-pip/46979531#46979531
RUN aria2c https://excellmedia.dl.sourceforge.net/project/rna-cpat/v1.2.3/CPAT-1.2.3.tar.gz -q -o /opt/CPAT-1.2.3.tar.gz && \
	tar xf /opt/CPAT-1.2.3.tar.gz --use-compress-prog=pigz -C /opt/ && \
	cd /opt/CPAT-1.2.3/ && \
	perl -i -lanE'say unless $. == 21' setup.py && \
	python setup.py install && \
	rm -rfv !"dat" && \
	chmod -R 777 *
	
# Install FastQC
RUN aria2c https://www.bioinformatics.babraham.ac.uk/projects/fastqc/fastqc_v0.11.5.zip -q -o /opt/fastqc_v0.11.5.zip && \
	unzip -qq /opt/fastqc_v0.11.5.zip -d /opt/ && \
	rm /opt/fastqc_v0.11.5.zip && \
	cd /opt/FastQC && \
	shopt -s extglob && \
	rm -rfv !\("fastqc"\|*.jar\) && \
	chmod 777 * && \
	ln -s /opt/FastQC/fastqc /usr/local/bin/

# Set back to default shell
SHELL ["/bin/sh", "-c"]
	
# Install StringTie
RUN aria2c http://ccb.jhu.edu/software/stringtie/dl/stringtie-1.3.3b.Linux_x86_64.tar.gz -q -o /opt/stringtie-1.3.3b.Linux_x86_64.tar.gz && \
	tar xf /opt/stringtie-1.3.3b.Linux_x86_64.tar.gz --use-compress-prog=pigz -C /opt/ && \
	rm /opt/stringtie-1.3.3b.Linux_x86_64/README && \
	ln -s /opt/stringtie-1.3.3b.Linux_x86_64/stringtie /usr/local/bin/stringtie && \
	rm /opt/stringtie-1.3.3b.Linux_x86_64.tar.gz

# Install Hisat2	
RUN aria2c ftp://ftp.ccb.jhu.edu/pub/infphilo/hisat2/downloads/hisat2-2.1.0-Linux_x86_64.zip -q -o /opt/hisat2-2.1.0-Linux_x86_64.zip && \
	unzip -qq /opt/hisat2-2.1.0-Linux_x86_64.zip -d /opt/ && \
	rm /opt/hisat2-2.1.0-Linux_x86_64.zip && \
	cd /opt/hisat2-2.1.0 && \
	rm -rf doc example *debug MANUAL* NEWS TUTORIAL && \
	ln -s /opt/hisat2-2.1.0/hisat2* /usr/local/bin/ && \
	ln -sf /opt/hisat2-2.1.0/*.py /usr/local/bin/
	
# Install Kallisto
# There's some trashy pointers in Kallisto tarball archieve
RUN aria2c https://github.com/pachterlab/kallisto/releases/download/v0.43.1/kallisto_linux-v0.43.1.tar.gz -q -o  /opt/kallisto_linux-v0.43.1.tar.gz && \
	tar xf /opt/kallisto_linux-v0.43.1.tar.gz --use-compress-prog=pigz -C /opt/ && \
	cd /opt && \
	rm ._* kallisto_linux-v0.43.1.tar.gz && \
	cd kallisto_linux-v0.43.1 && \
	rm -rf ._* 	README.md test && \
	ln -s /opt/kallisto_linux-v0.43.1/kallisto /usr/local/bin/
	
# Install Microsoft-R-Open with MKL, you must use MRO v3.4.2 or later
# For more, see this GitHub issue comment: https://github.com/Microsoft/microsoft-r-open/issues/26#issuecomment-340276347
RUN aria2c https://mran.blob.core.windows.net/install/mro/3.5.0/microsoft-r-open-3.5.0.tar.gz -q -o /opt/microsoft-r-open-3.5.0.tar.gz && \
	tar xf /opt/microsoft-r-open-3.5.0.tar.gz --use-compress-prog=pigz -C /opt/ && \
	cd /opt/microsoft-r-open && \
	./install.sh -au && \
	rm -rf /opt/microsoft-r*

# Cleaning up the apt cache helps keep the image size down (must be placed here, since MRO installation need the cache)
RUN rm -rf /var/lib/apt/lists/*

# To fix problem by mozjepg (will cause error when running MRO)
# See https://github.com/tcoopman/image-webpack-loader/issues/95
RUN aria2c http://mirrors.kernel.org/ubuntu/pool/main/libp/libpng/libpng12-0_1.2.54-1ubuntu1_amd64.deb -q -o /tmp/libpng12.deb && \
	dpkg -i /tmp/libpng12.deb && \
	rm /tmp/libpng12.deb

# Setup R configs
RUN echo "r <- getOption('repos'); r['CRAN'] <- 'http://cran.us.r-project.org'; options(repos = r);" > ~/.Rprofile

# Install cpanminus
# RUN aria2c https://cpanmin.us/ -q -o /opt/cpanm && \
#	chmod +x /opt/cpanm && \
#	ln -s /opt/cpanm /usr/local/bin/

# Install Perl module FindBin, which is required by FastQC
# RUN cpanm FindBin
	
# Install Pandoc (required by reporter)
RUN aria2c https://github.com/jgm/pandoc/releases/download/1.19.2.1/pandoc-1.19.2.1-1-amd64.deb -q -o /opt/pandoc-1.19.2.1-1-amd64.deb && \
	dpkg -i /opt/pandoc-1.19.2.1-1-amd64.deb && \
	rm /opt/pandoc-1.19.2.1-1-amd64.deb
	
# Install PyPy
RUN aria2c https://bitbucket.org/squeaky/portable-pypy/downloads/pypy-5.9-linux_x86_64-portable.tar.bz2 -q -o /opt/pypy-5.9-linux_x86_64-portable.tar.bz2 && \
	tar xf /opt/pypy-5.9-linux_x86_64-portable.tar.bz2 --use-compress-prog=pbzip2 -C /opt/ && \
	rm /opt/pypy-5.9-linux_x86_64-portable/README.rst /opt/pypy-5.9-linux_x86_64-portable.tar.bz2 && \
	ln -s /opt/pypy-5.9-linux_x86_64-portable/bin/pypy /usr/local/bin/	

# Install BEDOPS
RUN aria2c https://github.com/bedops/bedops/releases/download/v2.4.29/bedops_linux_x86_64-v2.4.29.tar.bz2 -q -o /opt/bedops_linux_x86_64-v2.4.29.tar.bz2 && \
	tar xf /opt/bedops_linux_x86_64-v2.4.29.tar.bz2 --use-compress-prog=pbzip2 -C /opt/ && \
	ln -s /opt/bin/* /usr/local/bin/ && \
	rm /opt/bedops_linux_x86_64-v2.4.29.tar.bz2
	
# Install AfterQC
# Use PyPy to run AfterQC as default
RUN aria2c https://github.com/OpenGene/AfterQC/archive/v0.9.7.tar.gz -q -o /opt/AfterQC-0.9.7.tar.gz && \
	tar xf /opt/AfterQC-0.9.7.tar.gz --use-compress-prog=pigz -C /opt/ && \
	cd /opt/AfterQC-0.9.7 && \
	make && \
	perl -i -lape's/python/pypy/ if $. == 1' after.py && \
	rm -rf Dockerfile Makefile README.md testdata report_sample && \
	rm editdistance/*.cpp editdistance/*.h && \
	ln -s /opt/AfterQC-0.9.7/*.py /usr/local/bin/ && \
	rm /opt/AfterQC-0.9.7.tar.gz
	
# Install R package LncPipeReporter（via GitHub)
RUN Rscript -e "source('http://bioconductor.org/biocLite.R'); install.packages(c('curl', 'httr')); install.packages('devtools'); devtools::install_github('bioinformatist/LncPipeReporter')"
# Set privilege for save temporary results
RUN chmod -R 777 /opt/microsoft/ropen/3.5.0/lib64/R/library/LncPipeReporter

# Install GffCompare
RUN aria2c https://github.com/gpertea/gffcompare/archive/master.zip -q -o /opt/gffcompare-master.zip && \
	aria2c https://github.com/gpertea/gclib/archive/master.zip -q -o /opt/gclib-master.zip && \
	unzip -qq /opt/gffcompare-master.zip -d /opt/ && \
	unzip -qq /opt/gclib-master.zip -d /opt/ && \
	rm /opt/gffcompare-master.zip /opt/gclib-master.zip && \
	mv /opt/gclib-master /opt/gclib && \
	cd /opt/gffcompare-master && \
	make release && \
	rm Makefile README.md gtf_tracking.h *.o *.cpp *.sh && \
	ln -s /opt/gffcompare-master/gffcompare /usr/local/bin/

# Install sambamba
RUN aria2c https://github.com/biod/sambamba/releases/download/v0.6.7/sambamba_v0.6.7_linux.tar.bz2 -q -o /opt/sambamba_v0.6.7_linux.tar.bz2 && \
	tar xf /opt/sambamba_v0.6.7_linux.tar.bz2 --use-compress-prog=pbzip2 -C /opt/ && \
	ln -s /opt/sambamba /usr/local/bin/ && \
	rm /opt/sambamba_v0.6.7_linux.tar.bz2

# Install fastp
RUN aria2c http://opengene.org/fastp/fastp -q -o /usr/local/bin/fastp && \
	chmod a+x /usr/local/bin/fastp

# Change privilege permanently to fit NextFlow's volume settings
RUN echo "umask 000" >> /etc/profile


# Lines below maybe used in the future
# Install BWA
#RUN bash -c 'aria2c https://codeload.github.com/lh3/bwa/zip/master -q -o /opt/bwa-master.zip && \
#	unzip -qq /opt/bwa-master.zip -d /opt/ && \
#	rm /opt/bwa-master.zip && \
#	cd /opt/bwa-master && \
#	make > /dev/null 2>&1 && \
#	shopt -s extglob && \
#	rm -rfv !\("bwa"\|"qualfa2fq.pl"\|"xa2multi.pl"\|"COPYING"\) && \
#	ln -s /opt/bwa-master/bwa /usr/local/bin/ && \
#	ln -s /opt/bwa-master/*.pl /usr/local/bin/'
	
# Install SAMtools (incomplete)
#RUN aria2c https://github.com/samtools/samtools/releases/download/1.5/samtools-1.5.tar.bz2 -q -o /opt/samtools-1.5.tar.bz2 && \
#	tar xf /opt/samtools-1.5.tar.bz2 --use-compress-prog=pbzip2 -C /opt/ && \
#	cd /opt/samtools-1.5 && \
#	make && \
#	make install && \
#	rm /opt/samtools-1.5.tar.bz2
	
# Install BCFtools
# https://github.com/samtools/bcftools/releases/download/1.5/bcftools-1.5.tar.bz2
	
