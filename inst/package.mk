## This Makefile automates common tasks in R package developement
## Copyright (C) 2013 Renaud Gaujoux

#%AUTHOR_USER%#
#%R_PACKAGE%#
#%R_PACKAGE_PROJECT_PATH%#
#%R_PACKAGE_PROJECT%#
#%R_PACKAGE_SUBPROJECT_PATH_PART%#
#%R_PACKAGE_OS%#
#%R_PACKAGE_PATH%#
#%R_PACKAGE_TAR_GZ%#

#%INIT_CHECK%#

ifndef R_PACKAGE
#$(error Required make variable 'R_PACKAGE' is not defined.)
endif
ifndef R_PACKAGE_PATH
R_PACKAGE_PATH=../pkg
endif

#ifndef R_LIBS
R_LIBS=#%R_LIBS%#
#endif

ifdef devel
RSCRIPT=Rdscript
RCMD=Rdevel
DEVEL_FLAG=-devel
CHECK_DIR=checks/devel
else
CHECK_DIR=checks
endif

R_BIN=#%R_BIN%#

ifndef RSCRIPT
RSCRIPT:=$(R_BIN)/Rscript
endif
ifndef RCMD
RCMD:=$(R_BIN)/R
endif

# VIGNETTES COMMAND
define CMD_VIGNETTES
library(devtools);
library(methods);
p <- as.package('$(R_PACKAGE_PATH)');
pdir <- p[['path']]
message("Package directory: ", pdir)
dev_mode(path=file.path(dirname(pdir), 'lib'))
library(pkgmaker);
tmp <- quickinstall(pdir, tempfile());
library(p[['package']], lib=tmp, character.only=TRUE) 
library(tools); 
buildVignettes(p[['package']])
endef

# BUILD-BINARIES COMMAND
define CMD_BUILD_BINARIES
library(devtools);
library(methods);
p <- as.package('$(R_PACKAGE_PATH)');
pdir <- p[['path']];
src <- paste0(p[['package']], '_', p[['version']], '.tar.gz')
run <- function(){
tmp <- tempfile()
on.exit( unlink(tmp, recursive=TRUE) )
cmd <- paste0("wine R CMD INSTALL -l ", tmp, ' --build ', src)
message("R CMD check command:\n", cmd)
system(cmd, intern=FALSE, ignore.stderr=FALSE)
}
run()
endef


all: roxygen build check 

dist: all staticdoc

init:

build:
	# Package '$(R_PACKAGE)' in project '$(R_PACKAGE_PROJECT)'
	# Source directory: '$(R_PACKAGE_PATH)'
	# Project directory: '$(R_PACKAGE_PROJECT_PATH)'
	# Project sub-directory: '$(R_PACKAGE_SUBPROJECT_PATH_PART)'
	# Platform: $(R_PACKAGE_OS)
	@mkdir -p $(CHECK_DIR) && \
	cd $(CHECK_DIR) && \
	echo "\n*** STEP: BUILD\n" && \
	$(RCMD) CMD build $(R_PACKAGE_PATH) && \
	echo "*** DONE: BUILD"
	
build-bin: build
	@cd $(CHECK_DIR) && \
	echo "\n*** STEP: BUILD-BINARIES\n" && \
	`echo "$$CMD_BUILD_BINARIES" > build-bin.r` && \
	$(RSCRIPT) --vanilla ./build-bin.r && \
	echo "\n*** DONE: BUILD-BINARIES"
	
check: build $(CHECK_DIR)/$(R_PACKAGE_TAR_GZ)
	@cd $(CHECK_DIR) && \
	echo "\n*** STEP: CHECK\n" && \
	mkdir -p $(R_PACKAGE_OS) && \
	$(R_LIBS) $(RCMD) CMD check -o $(R_PACKAGE_OS) --as-cran --timings $(R_PACKAGE_TAR_GZ) 
	echo "\n*** DONE: CHECK"

roxygen: init
	@cd $(CHECK_DIR) && \
	echo "\n*** STEP: ROXYGEN\n" && \
	roxy $(R_PACKAGE) && \
	echo "\n*** DONE: ROXYGEN"

staticdocs: init
	@cd $(CHECK_DIR) && \
	echo "\n*** STEP: STATICDOCS\n" && \
	Rstaticdocs $(R_PACKAGE) && \
	echo "\n*** DONE: STATICDOCS\n"

ifdef rebuild
vignettes: init rmvignettes
else
vignettes: init
endif
	@cd $(CHECK_DIR) && \
	cd $(R_PACKAGE_PATH)/vignettes && \
	echo "\n*** STEP: BUILD VIGNETTES\n" && \
	make && \
	echo "Cleaning up ..." && \
	make clean && \
	echo "\n*** DONE: BUILD VIGNETTES\n"

rmvignettes:
	@cd $(CHECK_DIR) && \
	cd $(R_PACKAGE_PATH)/vignettes && \
	echo "\n*** STEP: REMOVE VIGNETTES\n" && \
	make clean-all && \
	echo "\n*** DONE: REMOVE VIGNETTES\n"
	
r-forge: build
	@cd $(CHECK_DIR) && \
	echo "\n*** STEP: R-FORGE" && \
	echo -n "  - package source ... " && \
	tar xzf $(R_PACKAGE_TAR_GZ) -C ../r-forge/pkg$(R_PACKAGE_SUBPROJECT_PATH_PART)/ --strip 1 $(R_PACKAGE) && \
	echo "OK" && \
	echo -n "  - static doc ... " && \
	rsync --delete --recursive --cvs-exclude $(R_PACKAGE_PROJECT_PATH)/www$(R_PACKAGE_SUBPROJECT_PATH_PART)/ ../r-forge/www$(R_PACKAGE_SUBPROJECT_PATH_PART)/ && \
	echo "OK" && \
	echo "*** DONE: R-FORGE\n"
	
myCRAN: build
	@cd $(CHECK_DIR) && \
	echo "\n*** STEP: myCRAN" && \
	echo -n "  - package source ... " && \
	cp $(R_PACKAGE_TAR_GZ) ~/projects/myCRAN/src/contrib && \
	echo "OK" && \
	echo "  - update index ... " && \
	cd ~/projects/myCRAN/ && ./update && cd - && \
	echo "  - update staticdocs ... " && \
	cd ~/projects/myCRAN/ && rsync --delete --recursive --cvs-exclude $(R_PACKAGE_PROJECT_PATH)/www$(R_PACKAGE_SUBPROJECT_PATH_PART)/ web/$(R_PACKAGE)/ && \
	echo "DONE: index" && \
	echo "*** DONE: myCRAN\n"
