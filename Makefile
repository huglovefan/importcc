importcc: importcc.d
	gdc -O2 -g importcc.d -o $@
.PHONY: unittest
unittest:
	dmd -g -unittest -vtls -run importcc.d
