
templates	: run.json iteration.json sample.json period.json metric.json
		  ls -l *.json

run.json	: header run.base
		  ./build.sh run

iteration.json	: header run.base iteration.base
		  ./build.sh iteration run

sample.json	: header run.base iteration.base sample.base
		  ./build.sh sample iteration run

period.json	: header run.base iteration.base sample.base period.base
		  ./build.sh period sample iteration run

metric.json	: header run.base iteration.base sample.base period.base metric.base
		  ./build.sh metric period sample iteration run

clean		: 
		  /bin/rm *.json
