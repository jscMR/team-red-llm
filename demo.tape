# vhs demo.tape → produces demo.gif
# Run llama-server first: ./scripts/run-model.sh ~/models/Moonlight-16B-A3B-Instruct-Q6_K.gguf

Output demo.gif

Set FontSize 16
Set Width 1200
Set Height 700
Set Theme "Catppuccin Mocha"
Set TypingSpeed 40ms
Set PlaybackSpeed 1.0

Type "# RX 7900 GRE 16GB · Moonlight-16B-A3B-Instruct · Q6_K"
Enter
Sleep 800ms
Type "# 100 tok/s · all 28 layers in VRAM"
Enter
Sleep 1s
Enter

Type@30ms `curl -s http://localhost:8001/v1/chat/completions \`
Enter
Type@30ms `  -H 'Content-Type: application/json' \`
Enter
Type@30ms `  -d '{"model":"moonlight","messages":[{"role":"user","content":"Explica MoE en una frase."}],"stream":true}' \`
Enter
Type@30ms `  | grep -oP '"content":"[^"]*"' | sed 's/"content":"//;s/"$//' | tr -d '\n'`
Enter
Sleep 8s

Enter
Type "# https://github.com/jscMR/team-red-llm"
Enter
Sleep 3s
