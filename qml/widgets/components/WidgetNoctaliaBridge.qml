import QtQuick
import Quickshell.Io

Item {
    id: root

    property bool autoPollStatus: false
    property int pollInterval: 5000
    property bool daemonAvailable: true
    property var statusData: ({})
    property bool isBusy: false

    signal commandSucceeded(string command, string output)
    signal commandFailed(string command, int exitCode, string error)
    signal statusUpdated(var status)
    signal fallbackRequested(string feature)

    function send(subcommand, args) {
        if (!daemonAvailable) {
            root.fallbackRequested(subcommand);
            return;
        }

        const cmd = ["noctalia", "msg", subcommand];
        if (args && args.length > 0) {
            for (let i = 0; i < args.length; ++i) {
                cmd.push(String(args[i]));
            }
        }

        execProcess.targetCommand = subcommand;
        execProcess.command = cmd;
        root.isBusy = true;
        execProcess.running = true;
    }

    function pollStatus() {
        if (!daemonAvailable || statusProcess.running) return;
        statusProcess.accumulated = "";
        statusProcess.running = true;
    }

    Timer {
        id: pollTimer
        interval: root.pollInterval
        running: root.autoPollStatus && root.daemonAvailable && root.visible
        repeat: true
        triggeredOnStart: true
        onTriggered: root.pollStatus()
    }

    Process {
        id: execProcess
        property string targetCommand: ""
        running: false

        stdout: SplitParser {
            onRead: function(line) {
                root.commandSucceeded(execProcess.targetCommand, line.trim());
            }
        }

        stderr: SplitParser {
            onRead: function(line) {
                // Keep stderr active to prevent stream blocking
            }
        }

        onExited: function(exitCode) {
            root.isBusy = false;
            running = false;
            if (exitCode !== 0) {
                root.commandFailed(execProcess.targetCommand, exitCode, "Exit code " + exitCode);
                if (exitCode === 127) {
                    root.daemonAvailable = false;
                    root.fallbackRequested(execProcess.targetCommand);
                }
            }
        }
    }

    Process {
        id: statusProcess
        command: ["noctalia", "msg", "status"]
        running: false
        property string accumulated: ""

        stdout: SplitParser {
            onRead: function(line) {
                statusProcess.accumulated += line;
            }
        }

        stderr: SplitParser {
            onRead: function(line) {}
        }

        onExited: function(exitCode) {
            running = false;
            if (exitCode === 0 && statusProcess.accumulated.length > 0) {
                try {
                    const parsed = JSON.parse(statusProcess.accumulated);
                    root.statusData = parsed;
                    root.statusUpdated(parsed);
                } catch(e) {
                    console.warn("[NoctaliaBridge] Failed to parse status JSON:", e);
                }
            } else if (exitCode === 127) {
                root.daemonAvailable = false;
                root.fallbackRequested("status");
            }
            statusProcess.accumulated = "";
        }
    }
}
