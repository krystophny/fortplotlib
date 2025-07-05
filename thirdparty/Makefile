all: fetch-stb-truetype

ref: fetch-matplotlib fetch-pyplot-fortran fetch-stb-image

fetch-stb-truetype:
	curl -L https://github.com/nothings/stb/raw/refs/heads/master/stb_truetype.h -o stb_truetype.h

fetch-stb-image:
	curl -L https://github.com/nothings/stb/raw/refs/heads/master/stb_image.h -o stb_image.h
	curl -L https://github.com/nothings/stb/raw/refs/heads/master/stb_image_write.h -o stb_image_write.h

fetch-matplotlib:
	curl -L https://github.com/matplotlib/matplotlib/archive/refs/tags/v3.10.3.tar.gz | tar xz
	mv matplotlib-3.10.3 matplotlib

fetch-pyplot-fortran:
	git clone --depth 1 https://github.com/jacobwilliams/pyplot-fortran.git

fetch-mpeg:
	git clone --depth 1 https://github.com/maikmerten/mpeg.git

clean:
	rm -rf matplotlib
	rm -rf pyplot-fortran

.PHONY: all ref clean fetch-matplotlib fetch-pyplot-fortran
