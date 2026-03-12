const statusText = document.getElementById("statusText");
const detailText = document.getElementById("detailText");
const finalTranscript = document.getElementById("finalTranscript");
const partialTranscript = document.getElementById("partialTranscript");
const startButton = document.getElementById("startButton");
const stopButton = document.getElementById("stopButton");
const clearButton = document.getElementById("clearButton");

let audioContext = null;
let mediaStream = null;
let processorNode = null;
let sourceNode = null;
let websocket = null;

startButton.addEventListener("click", () => {
  startStreaming().catch((error) => setError(error.message));
});

stopButton.addEventListener("click", () => {
  stopStreaming("Stopped by user.").catch((error) => setError(error.message));
});

clearButton.addEventListener("click", () => {
  finalTranscript.textContent = "";
  partialTranscript.textContent = "Waiting for speech...";
});

async function startStreaming() {
  if (websocket) {
    return;
  }

  setStatus("connecting", "Connecting", "Requesting microphone permission and opening the ASR session.");

  mediaStream = await navigator.mediaDevices.getUserMedia({ audio: true });
  audioContext = new AudioContext();
  sourceNode = audioContext.createMediaStreamSource(mediaStream);
  processorNode = audioContext.createScriptProcessor(4096, 1, 1);
  sourceNode.connect(processorNode);
  processorNode.connect(audioContext.destination);

  websocket = new WebSocket(toWebSocketUrl(window.location.origin));
  websocket.addEventListener("open", () => {
    websocket.send(JSON.stringify({ type: "start", language: "auto" }));
    setStatus("live", "Live", "Listening... speak naturally and the text will appear below.");
    startButton.disabled = true;
    stopButton.disabled = false;
  });

  websocket.addEventListener("message", (event) => {
    const payload = JSON.parse(event.data);
    if (payload.type === "partial") {
      partialTranscript.textContent = payload.text || "Listening...";
      return;
    }
    if (payload.type === "session_final") {
      const existing = finalTranscript.textContent.trim();
      finalTranscript.textContent = [existing, payload.text].filter(Boolean).join("\n");
      partialTranscript.textContent = "Waiting for speech...";
      return;
    }
    if (payload.type === "error") {
      setError(`${payload.code}: ${payload.message}`);
    }
  });

  websocket.addEventListener("close", () => {
    websocket = null;
    startButton.disabled = false;
    stopButton.disabled = true;
    teardownAudio();
    if (!statusText.classList.contains("error")) {
      setStatus("idle", "Idle", "Microphone session is closed.");
    }
  });

  websocket.addEventListener("error", () => {
    setError("WebSocket connection failed.");
  });

  processorNode.onaudioprocess = (event) => {
    if (!websocket || websocket.readyState !== WebSocket.OPEN) {
      return;
    }
    const input = event.inputBuffer.getChannelData(0);
    const pcm16 = convertFloatTo16kPCM(input, audioContext.sampleRate);
    if (pcm16.byteLength === 0) {
      return;
    }
    websocket.send(
      JSON.stringify({
        type: "audio_chunk",
        audio: bytesToBase64(pcm16),
      }),
    );
  };
}

async function stopStreaming(detail = "Stopping session...") {
  setStatus("connecting", "Stopping", detail);
  if (websocket && websocket.readyState === WebSocket.OPEN) {
    websocket.send(JSON.stringify({ type: "finish" }));
  } else {
    teardownAudio();
    setStatus("idle", "Idle", "Microphone session is closed.");
  }
}

function teardownAudio() {
  processorNode?.disconnect();
  sourceNode?.disconnect();
  processorNode = null;
  sourceNode = null;

  if (mediaStream) {
    for (const track of mediaStream.getTracks()) {
      track.stop();
    }
  }
  mediaStream = null;

  audioContext?.close();
  audioContext = null;
}

function setStatus(kind, label, detail) {
  statusText.textContent = label;
  statusText.className = `status ${kind}`;
  detailText.textContent = detail;
}

function setError(message) {
  if (websocket && websocket.readyState <= WebSocket.OPEN) {
    websocket.close();
  }
  teardownAudio();
  setStatus("error", "Error", message);
  startButton.disabled = false;
  stopButton.disabled = true;
}

function toWebSocketUrl(origin) {
  if (origin.startsWith("https://")) {
    return `${origin.replace("https://", "wss://")}/v1/asr/stream`;
  }
  return `${origin.replace("http://", "ws://")}/v1/asr/stream`;
}

function convertFloatTo16kPCM(input, inputSampleRate) {
  if (!input.length) {
    return new Uint8Array();
  }

  const outputSampleRate = 16000;
  const ratio = inputSampleRate / outputSampleRate;
  const outputLength = Math.max(1, Math.round(input.length / ratio));
  const result = new Int16Array(outputLength);

  let offsetResult = 0;
  let offsetBuffer = 0;
  while (offsetResult < result.length) {
    const nextOffsetBuffer = Math.round((offsetResult + 1) * ratio);
    let sum = 0;
    let count = 0;

    for (let i = offsetBuffer; i < nextOffsetBuffer && i < input.length; i += 1) {
      sum += input[i];
      count += 1;
    }

    const sample = count > 0 ? sum / count : 0;
    const clamped = Math.max(-1, Math.min(1, sample));
    result[offsetResult] = clamped < 0 ? clamped * 0x8000 : clamped * 0x7fff;
    offsetResult += 1;
    offsetBuffer = nextOffsetBuffer;
  }

  return new Uint8Array(result.buffer);
}

function bytesToBase64(bytes) {
  let binary = "";
  for (let i = 0; i < bytes.byteLength; i += 1) {
    binary += String.fromCharCode(bytes[i]);
  }
  return btoa(binary);
}
