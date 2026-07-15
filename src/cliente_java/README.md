# Java Client - Network, Input and State

Source code of the Java module used by Processing.

Compile manually, if needed:

```bash
rm -rf out client.jar
mkdir out
javac -encoding UTF-8 -d out $(find src -name "*.java")
jar cf client.jar -C out .
```

Then copy `client.jar` to:

```text
../cliente_processing/MiniJogo/code/client.jar
```
