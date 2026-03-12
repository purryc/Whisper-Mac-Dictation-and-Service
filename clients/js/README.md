# whispercpp-asr-client

JavaScript SDK for the local ASR gateway.

## Install

```bash
cd /Users/hmi/Documents/my\ skills/whispercpp-realtime-asr/clients/js
npm install
npm run build
```

## File transcription

```ts
import { WhisperCppASRClient } from "whispercpp-asr-client";

const client = new WhisperCppASRClient("http://127.0.0.1:8765");
const result = await client.transcribe({
  audio: new Blob([audioBytes]),
  filename: "sample.wav",
  language: "auto",
});

console.log(result);
```

## Realtime streaming

```ts
import { WhisperCppASRClient } from "whispercpp-asr-client";

const client = new WhisperCppASRClient("http://127.0.0.1:8765");
const session = client.createRealtimeSession();

await session.connect();
session.onEvent((event) => {
  console.log(event);
});
await session.start({ language: "auto" });
await session.sendAudioChunk(pcm16Chunk);
await session.finish();
```
