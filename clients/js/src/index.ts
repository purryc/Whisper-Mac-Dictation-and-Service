export type TranscribeOptions = {
  audio: Blob | Uint8Array | ArrayBuffer;
  filename?: string;
  language?: string;
  prompt?: string;
};

export type RealtimeStartOptions = {
  language?: string;
  prompt?: string;
};

export type TranscriptResponse = {
  text: string;
  language: string;
  duration_ms: number;
  engine: string;
  metadata?: Record<string, unknown>;
};

export type CapabilitiesResponse = {
  transport: { http: boolean; websocket: boolean };
  ui?: { enabled: boolean; path: string };
  streaming_audio: {
    encoding: string;
    sample_rate: number;
    channels: number;
  };
  engine: { configured: boolean; name: string };
};

export type SessionStartedEvent = {
  type: "session_started";
  sample_rate: number;
  channels: number;
};

export type PartialEvent = {
  type: "partial";
  text: string;
  is_final: false;
};

export type SessionFinalEvent = {
  type: "session_final";
  text: string;
  is_final: true;
  duration_ms: number;
  language: string;
  engine: string;
};

export type ErrorEvent = {
  type: "error";
  code: string;
  message: string;
};

export type GenericEvent = {
  type: string;
  [key: string]: unknown;
};

export type ASREvent =
  | SessionStartedEvent
  | PartialEvent
  | SessionFinalEvent
  | ErrorEvent
  | GenericEvent;

export class WhisperCppASRClient {
  private readonly baseUrl: string;

  constructor(baseUrl = "http://127.0.0.1:8765") {
    this.baseUrl = baseUrl.replace(/\/$/, "");
  }

  async capabilities(): Promise<CapabilitiesResponse> {
    const response = await fetch(`${this.baseUrl}/v1/asr/capabilities`);
    return this.parseJsonResponse<CapabilitiesResponse>(response);
  }

  async transcribe(options: TranscribeOptions): Promise<TranscriptResponse> {
    const formData = new FormData();
    formData.set(
      "file",
      toBlob(options.audio),
      options.filename ?? "audio.wav",
    );
    if (options.language) {
      formData.set("language", options.language);
    }
    if (options.prompt) {
      formData.set("prompt", options.prompt);
    }

    const response = await fetch(`${this.baseUrl}/v1/asr/transcribe`, {
      method: "POST",
      body: formData,
    });
    return this.parseJsonResponse<TranscriptResponse>(response);
  }

  createRealtimeSession(wsUrl?: string): RealtimeASRSession {
    return new RealtimeASRSession(wsUrl ?? toWebSocketUrl(this.baseUrl));
  }

  private async parseJsonResponse<T>(response: Response): Promise<T> {
    const data = await response.json();
    if (!response.ok) {
      throw new Error(
        typeof data?.message === "string" ? data.message : `Request failed with status ${response.status}`,
      );
    }
    return data as T;
  }
}

export class RealtimeASRSession {
  private readonly wsUrl: string;
  private socket: WebSocket | null = null;
  private listeners = new Set<(event: ASREvent) => void>();

  constructor(wsUrl = "ws://127.0.0.1:8765/v1/asr/stream") {
    this.wsUrl = wsUrl;
  }

  async connect(): Promise<void> {
    if (this.socket && this.socket.readyState <= WebSocket.OPEN) {
      return;
    }

    await new Promise<void>((resolve, reject) => {
      const socket = new WebSocket(this.wsUrl);
      socket.onopen = () => {
        this.socket = socket;
        resolve();
      };
      socket.onerror = () => reject(new Error("Failed to open ASR WebSocket connection."));
      socket.onmessage = (message) => {
        const event = JSON.parse(String(message.data)) as ASREvent;
        for (const listener of this.listeners) {
          listener(event);
        }
      };
      socket.onclose = () => {
        this.socket = null;
      };
    });
  }

  onEvent(listener: (event: ASREvent) => void): () => void {
    this.listeners.add(listener);
    return () => this.listeners.delete(listener);
  }

  async start(options: RealtimeStartOptions = {}): Promise<void> {
    await this.send({
      type: "start",
      language: options.language,
      prompt: options.prompt,
    });
  }

  async sendAudioChunk(chunk: Uint8Array | ArrayBuffer): Promise<void> {
    const bytes = chunk instanceof Uint8Array ? chunk : new Uint8Array(chunk);
    await this.send({
      type: "audio_chunk",
      audio: encodeBase64(bytes),
    });
  }

  async ping(): Promise<void> {
    await this.send({ type: "ping" });
  }

  async finish(): Promise<void> {
    await this.send({ type: "finish" });
  }

  close(): void {
    this.socket?.close();
    this.socket = null;
  }

  private async send(payload: Record<string, unknown>): Promise<void> {
    if (!this.socket || this.socket.readyState !== WebSocket.OPEN) {
      throw new Error("Realtime ASR socket is not connected.");
    }
    const cleanPayload = Object.fromEntries(
      Object.entries(payload).filter(([, value]) => value !== undefined),
    );
    this.socket.send(JSON.stringify(cleanPayload));
  }
}

function toBlob(audio: Blob | Uint8Array | ArrayBuffer): Blob {
  if (audio instanceof Blob) {
    return audio;
  }
  const bytes = audio instanceof Uint8Array ? audio : new Uint8Array(audio);
  const safeBytes = new Uint8Array(bytes.byteLength);
  safeBytes.set(bytes);
  return new Blob([safeBytes], { type: "application/octet-stream" });
}

function toWebSocketUrl(baseUrl: string): string {
  if (baseUrl.startsWith("https://")) {
    return `${baseUrl.replace("https://", "wss://")}/v1/asr/stream`;
  }
  return `${baseUrl.replace("http://", "ws://")}/v1/asr/stream`;
}

function encodeBase64(bytes: Uint8Array): string {
  const maybeBuffer = (globalThis as typeof globalThis & {
    Buffer?: { from(input: Uint8Array): { toString(encoding: string): string } };
  }).Buffer;

  if (maybeBuffer) {
    return maybeBuffer.from(bytes).toString("base64");
  }

  let binary = "";
  for (const byte of bytes) {
    binary += String.fromCharCode(byte);
  }
  return btoa(binary);
}
