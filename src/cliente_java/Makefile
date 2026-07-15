compile:
	rm -rf out client.jar
	mkdir out
	javac -encoding UTF-8 -d out $$(find src -name "*.java")
	jar cf client.jar -C out .
	cp client.jar ../cliente_processing/MiniJogo/code/client.jar

clean:
	rm -rf out client.jar
