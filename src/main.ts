type MainToWorkerMessage =
    | { type: 'START'; intervalMs: number }
    | { type: 'STOP' }
    | { type: 'SET_INTERVAL'; intervalMs: number };

type WorkerToMainMessage =
    | { type: 'TICK' };

interface SubbeatPattern {
    subdivisions: number;
    mask: boolean[];
}

interface MetronomeConfig {
    beatsPerMinute: number;
    beatsPerMeasure: number;
    markFirstBeat: boolean;
    subbeatPattern: SubbeatPattern;
}

/**
 * The primary Main Thread Audio Coordinator.
 * Bridges worker-thread heartbeats to precise Web Audio API timeline events.
 */
class MetronomeEngine {
    private audioCtx: AudioContext | null = null;
    private worker: Worker;

    private isPlaying: boolean = false;
    private config: MetronomeConfig;

    private currentBeatIndex: number = 0;
    private nextBeatTime: number = 0.0;

    // Lookahead parameters: 100ms safety buffer window, worker fires every 25ms
    private readonly lookaheadSeconds: number = 0.100;
    private readonly scheduleIntervalMs: number = 25;

    /**
     * @param config Initial metronome behavior profiles.
     * @param worker Pre-instantiated Worker thread instance.
     */
    constructor(config: MetronomeConfig, worker: Worker) {
        this.config = config;
        this.worker = worker;

        // Route worker ticks into our localized scheduler
        this.worker.addEventListener('message', (event: MessageEvent<{ type: string }>) => {
            if (event.data.type === 'TICK') {
                this.handleWorkerTick();
            }
        });
    }

    /**
     * Initializes or wakes up the browser's audio hardware engine.
     * Must be called directly within a user gesture thread (e.g., click handler).
     */
    public initAudio(): void {
        if (!this.audioCtx) {
            this.audioCtx = new AudioContext();
        } else if (this.audioCtx.state === 'suspended') {
            this.audioCtx.resume();
        }
    }

    /**
     * Activates the metronome loop and syncs timeline parameters.
     */
    public start(): void {
        if (this.isPlaying) return;

        this.initAudio();
        if (!this.audioCtx) return;

        this.isPlaying = true;
        this.currentBeatIndex = 0;

        // Lock timing onto the exact current time of the hardware clock
        this.nextBeatTime = this.audioCtx.currentTime;

        // Signal background worker thread to begin the heartbeat loop
        this.worker.postMessage({ type: 'START', intervalMs: this.scheduleIntervalMs });
    }

    /**
     * Disables the metronome playback state instantly.
     */
    public stop(): void {
        if (!this.isPlaying) return;

        this.isPlaying = false;
        this.worker.postMessage({ type: 'STOP' });
    }

    /**
     * Updates configuration references seamlessly on the fly.
     * @param newConfig Fractional subset of options to blend into state.
     */
    public updateConfig(newConfig: Partial<MetronomeConfig>): void {
        this.config = { ...this.config, ...newConfig };
    }

    /**
     * Captured interceptor for worker threads notifications.
     */
    private handleWorkerTick(): void {
        if (!this.isPlaying) return;
        this.scheduler();
    }

    /**
     * Tracks the lookahead timing queue and cascades events down to the audio subsystem.
     */
    private scheduler(): void {
        if (!this.audioCtx) return;

        // While an upcoming event falls inside our ahead-of-time lookahead window
        while (this.nextBeatTime < this.audioCtx.currentTime + this.lookaheadSeconds) {
            const beatDurationSeconds = 60.0 / this.config.beatsPerMinute;

            // Schedule the downbeat and any of its embedded subbeat pulses
            this.scheduleBeat(this.currentBeatIndex, this.nextBeatTime, beatDurationSeconds);

            // Shift timeline tracking forward by one complete structural beat increment
            this.nextBeatTime += beatDurationSeconds;

            // Roll over measure boundaries smoothly using basic module math
            this.currentBeatIndex = (this.currentBeatIndex + 1) % this.config.beatsPerMeasure;
        }
    }

    /**
     * Segments a core beat block into granular subbeat steps and filters them via the pattern mask.
     */
    private scheduleBeat(beatIndex: number, beatStartTimeSeconds: number, beatDurationSeconds: number): void {
        const { subdivisions, mask } = this.config.subbeatPattern;
        if (subdivisions <= 0) return;

        const subbeatStepSeconds = beatDurationSeconds / subdivisions;

        for (let i = 0; i < subdivisions; i++) {
            // Drop execution if the mask explicitly flags this slot as silent
            if (!mask[i]) continue;

            const targetTime = beatStartTimeSeconds + (i * subbeatStepSeconds);

            // Assign specific frequencies to give auditory cues to the performer
            let frequencyHz = 600; // Base subbeat tick profile

            if (i === 0) {
                // Downbeats are louder/higher; primary measure hits are accented if requested
                frequencyHz = (beatIndex === 0 && this.config.markFirstBeat) ? 1200 : 900;
            }

            // Duration remains crisp: 50ms for major downbeats, 25ms for rapid inner subbeats
            const noteDuration = i === 0 ? 0.050 : 0.025;
            this.playTone(targetTime, frequencyHz, noteDuration);
        }
    }

    private playTone(timeSeconds: number, frequencyHz: number, durationSeconds: number): void {
        if (!this.audioCtx) return;

        // Instantiate transient audio blocks
        const osc = this.audioCtx.createOscillator();
        const gainNode = this.audioCtx.createGain();

        osc.type = 'triangle'; // Smooth woodblock-like sound profile
        osc.frequency.setValueAtTime(frequencyHz, timeSeconds);

        // Envelope shaping: Avoid audio pops by cascading gain cleanly down to 0
        gainNode.gain.setValueAtTime(1.0, timeSeconds);
        gainNode.gain.exponentialRampToValueAtTime(0.001, timeSeconds + durationSeconds);

        // Map audio signal: Oscillator -> Volume Volume Envelope -> Output Speakers
        osc.connect(gainNode);
        gainNode.connect(this.audioCtx.destination);

        // Enqueue life expectancy limits directly on the audio engine thread
        osc.start(timeSeconds);
        osc.stop(timeSeconds + durationSeconds);
    }
}

function bootstrapWorker(): Worker {
    const workerCode = `___BUILDSCRIPT_INLINES_WORKER_JS_HERE___`;
    const blob = new Blob([workerCode], { type: 'application/javascript' });
    const workerUrl = URL.createObjectURL(blob);
    const worker = new Worker(workerUrl);
    URL.revokeObjectURL(workerUrl);
    return worker;
}

/**
 * Orchestrates DOM element binding and application initialization.
 */
function initApp(): void {
    const startBtn = document.getElementById('startBtn') as HTMLButtonElement;
    const stopBtn = document.getElementById('stopBtn') as HTMLButtonElement;
    const bpmRange = document.getElementById('bpmRange') as HTMLInputElement;
    const bpmValue = document.getElementById('bpmValue') as HTMLSpanElement;
    const beatsRange = document.getElementById('beatsRange') as HTMLInputElement;
    const beatsValue = document.getElementById('beatsValue') as HTMLSpanElement;
    const patternSelect = document.getElementById('patternSelect') as HTMLSelectElement;

    const initialConfig: MetronomeConfig = {
        beatsPerMinute: 120,
        beatsPerMeasure: 4,
        markFirstBeat: true,
        subbeatPattern: {
            subdivisions: 1,
            mask: [true]
        }
    };

    // Spin up the background worker and engine instances
    const worker = bootstrapWorker();
    const metronome = new MetronomeEngine(initialConfig, worker);

    // 4. Bind action hooks to user interactions
    startBtn.addEventListener('click', () => {
        metronome.start();
        startBtn.disabled = true;
        stopBtn.disabled = false;
    });

    stopBtn.addEventListener('click', () => {
        metronome.stop();
        startBtn.disabled = false;
        stopBtn.disabled = true;
    });

    bpmRange.addEventListener('input', (event) => {
        const target = event.target as HTMLInputElement;
        const newBpm = parseInt(target.value, 10);
        bpmValue.textContent = newBpm.toString();
        metronome.updateConfig({ beatsPerMinute: newBpm });
    });

    beatsRange.addEventListener('input', (event) => {
        const target = event.target as HTMLInputElement;
        const newBeats = parseInt(target.value, 10);
        beatsValue.textContent = newBeats.toString();
        metronome.updateConfig({ beatsPerMeasure: newBeats });
    });

    patternSelect.addEventListener('change', () => {
        const selectedOption = patternSelect.options[patternSelect.selectedIndex];
        const maskAttr = selectedOption.getAttribute('data-mask');

        if (maskAttr) {
            try {
                // Parse the string layout array safely into a true boolean element matrix
                const parsedMask: boolean[] = JSON.parse(maskAttr);

                // Subdivisions inherently equal total array slots assigned
                const subdivisionCount = parsedMask.length;

                metronome.updateConfig({
                    subbeatPattern: {
                        subdivisions: subdivisionCount,
                        mask: parsedMask
                    }
                });
            } catch (err) {
                console.error("Failed to parse pattern mask configuration format:", err);
            }
        }
    });
}

window.addEventListener('DOMContentLoaded', initApp);

let foo = "Hi from the main thread";
console.log(foo);
