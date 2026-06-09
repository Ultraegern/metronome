/**
 * Manages the high-precision background timer loop running inside the Web Worker.
 * * By maintaining a steady heartbeat decoupled from the browser's main UI thread,
 * this state machine prevents tempo lagging and stuttering when the application
 * is running in background tabs or under heavy rendering load.
 */
class MetronomeWorkerState {
    /** The native browser timer resource handle. Null if the metronome is idle. */
    private timerId: number | null = null;

    /** The polling interval frequency in milliseconds. Defaults to a 25ms safety lookahead window. */
    private intervalMs: number = 25;

    /**
     * Binds the global worker 'message' event listener to the state machine.
     * Uses an arrow function callback to preserve the `this` context.
     */
    public init(): void {
        self.addEventListener('message', (event: MessageEvent<MainToWorkerMessage>) => {
            this.handleMessage(event);
        });
    }

    /**
     * Decodes the MainToWorkerMessage and dispatches execution.
     * Type narrowing automatically unlocks the payload fields.
     */
    private handleMessage(event: MessageEvent<MainToWorkerMessage>): void {
        const message = event.data;

        switch (message.type) {
            case 'START':
                this.intervalMs = message.intervalMs;
                this.start();
                break;
            case 'STOP':
                this.stop();
                break;
            case 'SET_INTERVAL':
                this.setIntervalTime(message.intervalMs);
                break;
        }
    }

    /**
     * Starts the high-precision ticker loop if it isn't running already.
     */
    private start(): void {
        // Guard to prevent leaking multiple concurrent intervals
        if (this.timerId !== null) {
            return;
        }

        this.timerId = self.setInterval(() => {
            self.postMessage({ type: 'TICK' });
        }, this.intervalMs);
    }

    /**
     * Clears the active ticker loop and resets the handle state.
     */
    private stop(): void {
        if (this.timerId !== null) {
            self.clearInterval(this.timerId);
            this.timerId = null;
        }
    }

    /**
     * Updates the interval period on the fly.
     * If running, it hot-swaps the loop instantly to prevent timing stutter.
     */
    private setIntervalTime(ms: number): void {
        this.intervalMs = ms;

        if (this.timerId !== null) {
            this.stop();
            this.start();
        }
    }
}

const workerState = new MetronomeWorkerState();
workerState.init();

console.log("Hi from the worker thread");
