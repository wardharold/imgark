archiver-src = $(wildcard cmd/archiver/*.go) \
												   $(wildcard pkg/archiver/*.go)
labeler-src  = $(wildcard cmd/labeler/*.go) \
												   $(wildcard pkg/labeler/*.go)
receiver-src = $(wildcard cmd/receiver/*.go) \
												   $(wildcard pkg/receiver/*.go)
common-src   = $(wildcard pkg/cmd/*.go) \
												   $(wildcard pkg/satokensource/*.go) \
															$(wildcard pkg/sdlog/*.go)

archiver-chart = chart/archiver/Chart.yaml
labeler-chart  = chart/labeler/Chart.yaml
receiver-chart = chart/receiver/Chart.yaml

archiver-img   = build/archiver.yaml
labeler-img    = build/labeler.yaml
receiver-img   = build/receiver.yaml

builds = archiver.build \
									labeler.build \
									receiver.build

charts = archiver.chart \
									labeler.chart \
									receiver.chart

chartmuseum-base-url = "http://localhost:8888"
helm-pkgdir = chart

define build-image =
gcloud container builds submit --config $< . --substitutions=_BRANCH_NAME=$$(git rev-parse --abbrev-ref HEAD | tr '/' '-'),_COMMIT_SHA=$$(git rev-parse --verify HEAD) > $@ 2>&1 ; if [ $$? -ne 0 ] ; then rm $@ ; echo "$@ failed" ; fi
endef

define package-chart =
helm package -d $(helm-pkgdir) $(dir $<)  > $@ 2>&1; if [ $$? -ne 0 ] ; then rm $@ ; echo "build failed: archiver" ; else curl --data-binary "@$$(cut -d' ' -f8 < $@)" $(chartmuseum-base-url)/api/charts ; fi
endef

# all: images imgark.chart
all: images


.PHONY: images
images: $(builds) ${charts}

archiver.build: $(archiver-img) $(archiver-src) $(common-src)
	$(build-image)

labeler.build: $(labeler-img) $(labeler-src) $(common-src)
	$(build-image)

receiver.build: $(receiver-img) $(receiver-src) $(common-src)
	$(build-image)

.PHONY: charts
charts: $(charts)

archiver.chart: $(archiver-chart)
	$(package-chart)
	@helm repo update

labeler.chart: $(labeler-chart)
	$(package-chart)
	@helm repo update

receiver.chart: $(receiver-chart)
	$(package-chart)
	@helm repo update

.PHONY: clean
clean: 
	@for bld in $(builds) ; do if [ -e $${bld} ] ; then rm $${bld} ; fi ; done
	@for cht in $(charts) ; do if [ -e $${cht} ] ; then rm $${cht} ; fi ; done
