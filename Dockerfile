FROM ubuntu

LABEL authors="zhaoqi@sysucc.org.cn,sun_yu@mail.nankai.edu.cn" \
	description="Docker image containing all requirements for LncPipe"

# Update OS
# Relieve the dependence of readline perl library by prohibiting interactive frontend first
RUN export DEBIAN_FRONTEND=noninteractive && \
	apt-get update &&\
	apt-get install -y --no-install-recommends \
	# For Nextflow (run groovy)
	default-jre \
	# For decompress GitHub archieve
	unzip \
	aria2 \
	# Below two is needed for CPAT and PLEK compiling
	gcc \
	g++ \
	# For exec makefile of libsvm-3.0 used by CNCI
	make \
	# Provide head file like Python.h for CPAT compiling
	python-dev \
	# Must install cython here, DO NOT use pip, which will causing missing .h files
	cython \
	# For CPAT compiling dependency
	zlib1g-dev \
	# Cleaning up the apt cache helps keep the image size down
	&& rm -rf /var/lib/apt/lists/*

# Install latest pip WITHOUT setuptools and wheel
# DO NOT use apt-get python-pip in ubuntu to prevent from complicated related tools and libraries
# Keep the image size down
RUN aria2c https://bootstrap.pypa.io/get-pip.py -q -o /opt/get-pip.py && \
    python /opt/get-pip.py --no-setuptools --no-wheel && \
    rm /opt/get-pip.py

# Install required python packages	
RUN pip -qqq install numpy
	
# Install nextflow
RUN aria2c https://github.com/nextflow-io/nextflow/releases/download/v0.25.6/nextflow -q -o /opt/nextflow && \
	ln -s /opt/nextflow /usr/local/bin
	
# Install STAR
RUN aria2c https://raw.githubusercontent.com/alexdobin/STAR/master/bin/Linux_x86_64/STAR -q -o /opt/STAR && \
    ln -s /opt/STAR/bin/Linux_x86_64/STAR /usr/local/bin

# Install cufflinks	
RUN aria2c https://github.com/bioinformatist/cufflinks/releases/download/v2.2.1/cufflinks-2.2.1.Linux_x86_64.tar.gz -q -o /opt/cufflinks-2.2.1.Linux_x86_64.tar.gz && \
	tar zxf /opt/cufflinks-2.2.1.Linux_x86_64.tar.gz -C /opt/ && \
	cd /opt/cufflinks-2.2.1.Linux_x86_64 && \
	rm AUTHORS LICENSE README && \
	ln -s /opt/cufflinks-2.2.1.Linux_x86_64/* /usr/local/bin/ && \
	rm /opt/cufflinks-2.2.1.Linux_x86_64.tar.gz
	
# Install CPAT
RUN aria2c https://jaist.dl.sourceforge.net/project/rna-cpat/v1.2.3/CPAT-1.2.3.tar.gz -q -o /opt/CPAT-1.2.3.tar.gz && \
	tar zxf /opt/CPAT-1.2.3.tar.gz -C /opt/ && \
	# DO NOT use absolute path here, changing directory is necessary, python interpreter will check current directory for dependencies
	cd /opt/CPAT-1.2.3/ && \
	python setup.py install && \
	rm -rf /opt/CPAT*
	
# Install PLEK
RUN aria2c https://nchc.dl.sourceforge.net/project/plek/PLEK.1.2.tar.gz -q -o /opt/PLEK.1.2.tar.gz && \
	tar zxf /opt/PLEK.1.2.tar.gz -C /opt/ && \
	cd /opt/PLEK.1.2/ && \
	python PLEK_setup.py || : && \
	# Remove documents, demo files, source files, object files and R scripts
	rm *.pdf *.txt *.h *.c *.model *.range *.fa *.cpp *.o *.R *.doc PLEK_setup.py && \
	chmod 755 * && \
	# dos2unix in perl one-liner: remove BOM head and deal with \r problem
	perl -CD -pi -e'tr/\x{feff}//d && s/[\r\n]+/\n/' *.py && \
	ln -s /opt/PLEK.1.2/* /usr/local/bin/ && \
	rm -rf /opt/PLEK.1.2.tar.gz

# Install CNCI
# Use bash instead of sh for shopt only works with bash 
RUN bash -c 'aria2c https://codeload.github.com/www-bioinfo-org/CNCI/zip/master -q -o /opt/CNCI-master.zip && \
	unzip /opt/CNCI-master.zip -d /opt/ && \
	rm /opt/CNCI-master.zip && \
	unzip /opt/CNCI-master/libsvm-3.0.zip -d /opt/CNCI-master/ && \
	rm /opt/CNCI-master/libsvm-3.0.zip && \
	cd /opt/CNCI-master/libsvm-3.0 && \
	make && \
	# enable the extglob shell option
	shopt -s extglob && \
	# Parentheses should be escaped
	rm -rfv !\("svm-predict"\|"svm-scale"\) && \
	cd .. && \
	rm draw_class_pie.R LICENSE README.md && \
	chmod -R 755 * && \
	ln -s /opt/CNCI-master/*.py /usr/local/bin/'
	
	