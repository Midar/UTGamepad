all:
	@objfw-compile --lib 0.0 -o utgamepad --package ObjFWHID UTGamepad.m

clean:
	rm -f *.o *.so
