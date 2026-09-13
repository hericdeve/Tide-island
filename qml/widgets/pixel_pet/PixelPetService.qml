pragma Singleton
import QtCore
import QtQuick
import Quickshell
import Quickshell.Io
import IslandBackend
import "PetCatalog.js" as PetCatalog

Item {
    id: root
    visible: false

    // ── Active Pet Identity & Wardrobe ────────────────────────────────────────
    property string activePetId: "cat"
    property string activeAccessoryId: "none"
    property var petData: PetCatalog.getPet(activePetId)
    property string customPetName: ""
    property string petName: customPetName !== "" ? customPetName : (petData ? petData.name : "Mochi")
    property string petSpecies: petData ? petData.species : "Calico Cat"

    // Care Pace & System Reactivity Preferences
    property string careMode: "normal" // "normal", "relaxed", "frozen"
    property bool reactToMusic: true
    property bool reactToCpu: true

    // ── Virtual Pet Vitals (0.0 to 100.0) ────────────────────────────────────
    property real hunger: 85.0
    property real happiness: 90.0
    property real energy: 95.0
    property real cleanliness: 100.0
    property int level: 1
    property int xp: 0
    readonly property int xpToNextLevel: level * 100

    // ── Behavioral & Animation State ─────────────────────────────────────────
    property string currentState: "idle" // idle, walk, happy, sleep, eat, stressed, jamming, play
    property bool isSleeping: false
    property int frameIndex: 0
    property bool flipX: false
    property real roamPosition: 0.5 // 0.0 (left) to 1.0 (right) in habitat

    // Dialogue & Thought bubbles
    property string speechBubbleText: "Purrr... ready to hang out! ✨"
    property string speechCategory: "greetings"

    // Particle System
    property string activeParticle: ""
    property real particleProgress: 0.0

    // Ball toss minigame state
    property bool isBallActive: false
    property real ballX: 0.5
    property real ballY: 0.5

    // ── System Reactivity Inputs (injected by host views) ─────────────────────
    property bool isMusicPlaying: false
    property string currentTrack: ""
    property real currentCpuUsage: 0.0
    property int batteryCapacity: 100
    property bool isCharging: true

    // ── Disk Persistence Store ────────────────────────────────────────────────
    FileView {
        id: petStorageFile
        path: StandardPaths.writableLocation(StandardPaths.GenericConfigLocation)
            + "/tide-island/pixel_pet.json"
        preload: true
        watchChanges: false
        atomicWrites: true
        printErrors: false

        JsonAdapter {
            id: petStore
            property string activePetId: "cat"
            property string activeAccessoryId: "none"
            property string customPetName: ""
            property string careMode: "normal"
            property bool reactToMusic: true
            property bool reactToCpu: true
            property real hunger: 85.0
            property real happiness: 90.0
            property real energy: 95.0
            property real cleanliness: 100.0
            property int level: 1
            property int xp: 0
            property double lastSavedTime: 0
        }

        onLoaded: root.loadFromStore()
    }

    Timer {
        id: saveDebounceTimer
        interval: 3000
        repeat: false
        onTriggered: root.commitToStore()
    }

    function loadFromStore() {
        if (!petStore) return;
        if (petStore.activePetId && PetCatalog.getPet(petStore.activePetId))
            root.activePetId = petStore.activePetId;
        if (petStore.activeAccessoryId)
            root.activeAccessoryId = petStore.activeAccessoryId;
        if (petStore.customPetName !== undefined)
            root.customPetName = petStore.customPetName;
        if (petStore.careMode)
            root.careMode = petStore.careMode;
        if (petStore.reactToMusic !== undefined)
            root.reactToMusic = petStore.reactToMusic;
        if (petStore.reactToCpu !== undefined)
            root.reactToCpu = petStore.reactToCpu;
        if (typeof petStore.hunger === "number")
            root.hunger = Math.max(0, Math.min(100, petStore.hunger));
        if (typeof petStore.happiness === "number")
            root.happiness = Math.max(0, Math.min(100, petStore.happiness));
        if (typeof petStore.energy === "number")
            root.energy = Math.max(0, Math.min(100, petStore.energy));
        if (typeof petStore.cleanliness === "number")
            root.cleanliness = Math.max(0, Math.min(100, petStore.cleanliness));
        if (typeof petStore.level === "number" && petStore.level >= 1)
            root.level = petStore.level;
        if (typeof petStore.xp === "number")
            root.xp = petStore.xp;

        root.petData = PetCatalog.getPet(root.activePetId);
        root.triggerSpeech("greetings");
    }

    function commitToStore() {
        if (!petStore) return;
        petStore.activePetId = root.activePetId;
        petStore.activeAccessoryId = root.activeAccessoryId;
        petStore.customPetName = root.customPetName;
        petStore.careMode = root.careMode;
        petStore.reactToMusic = root.reactToMusic;
        petStore.reactToCpu = root.reactToCpu;
        petStore.hunger = root.hunger;
        petStore.happiness = root.happiness;
        petStore.energy = root.energy;
        petStore.cleanliness = root.cleanliness;
        petStore.level = root.level;
        petStore.xp = root.xp;
        petStore.lastSavedTime = Date.now();
    }

    function requestSave() {
        saveDebounceTimer.restart();
    }

    // ── Frame Animation Stepper ───────────────────────────────────────────────
    Timer {
        id: animFrameTimer
        interval: (root.currentState === "jamming" || root.currentState === "happy") ? 220 : 380
        running: true
        repeat: true
        onTriggered: {
            root.frameIndex = (root.frameIndex + 1) % 8;
        }
    }

    // ── Particle Progression Stepper ──────────────────────────────────────────
    Timer {
        id: particleTimer
        interval: 40
        running: root.activeParticle !== ""
        repeat: true
        onTriggered: {
            root.particleProgress += 0.045;
            if (root.particleProgress >= 1.0) {
                root.activeParticle = "";
                root.particleProgress = 0.0;
            }
        }
    }

    function triggerParticle(type) {
        root.activeParticle = type;
        root.particleProgress = 0.01;
    }

    // ── Reaction Revert Timer ─────────────────────────────────────────────────
    Timer {
        id: reactionTimeoutTimer
        interval: 3200
        repeat: false
        onTriggered: {
            if (root.currentState === "happy" || root.currentState === "eat" || root.currentState === "stressed") {
                root.currentState = root.isSleeping ? "sleep" : "idle";
            }
        }
    }

    // ── Contextual Speech Engine ──────────────────────────────────────────────
    function triggerSpeech(category) {
        root.speechCategory = category;
        var p = root.petData || PetCatalog.getPet(root.activePetId);
        if (!p || !p.speech) return;
        var list = p.speech[category] || p.speech["greetings"];
        if (list && list.length > 0) {
            var idx = Math.floor(Math.random() * list.length);
            root.speechBubbleText = list[idx];
        }
    }

    // ── Autonomous AI Behavior Brain ──────────────────────────────────────────
    Timer {
        id: aiBehaviorTimer
        interval: 2200
        running: true
        repeat: true
        onTriggered: {
            // Priority 1: Temporary reactions lock state
            if (reactionTimeoutTimer.running) return;

            // Priority 2: Sleeping state
            if (root.isSleeping) {
                root.currentState = "sleep";
                if (Math.random() < 0.4) {
                    root.triggerParticle("zzz");
                }
                return;
            }

            // Priority 3: System Reactivity
            if (root.reactToMusic && root.isMusicPlaying) {
                root.currentState = "jamming";
                if (Math.random() < 0.35) {
                    root.triggerParticle("note");
                }
                if (Math.random() < 0.15) {
                    root.triggerSpeech("music");
                }
                return;
            }

            if (root.reactToCpu && root.currentCpuUsage > 80.0) {
                root.currentState = "stressed";
                if (Math.random() < 0.4) {
                    root.triggerParticle("sweat");
                }
                if (Math.random() < 0.2) {
                    root.triggerSpeech("stressed");
                }
                return;
            }

            // Priority 4: Low battery response
            if (!root.isCharging && root.batteryCapacity < 15) {
                if (Math.random() < 0.3) {
                    root.speechBubbleText = "Low battery... getting sleepy... ⚡";
                    root.triggerParticle("zzz");
                }
            }

            // Priority 5: Autonomous Roaming & Idle AI
            var roll = Math.random();
            if (roll < 0.40) {
                // Idle in place
                root.currentState = "idle";
            } else if (roll < 0.70) {
                // Walk right
                root.currentState = "walk";
                root.flipX = false;
                root.roamPosition = Math.min(0.9, root.roamPosition + 0.12);
            } else if (roll < 0.92) {
                // Walk left
                root.currentState = "walk";
                root.flipX = true;
                root.roamPosition = Math.max(0.1, root.roamPosition - 0.12);
            } else {
                // Quick happy hop
                root.currentState = "happy";
                reactionTimeoutTimer.interval = 1800;
                reactionTimeoutTimer.restart();
            }
        }
    }

    // ── Vitals Gentle Decay & Recovery Timer ──────────────────────────────────
    Timer {
        id: vitalsClock
        interval: 15000 // Every 15 seconds
        running: true
        repeat: true
        onTriggered: {
            if (root.careMode === "frozen") return;
            var decayMult = (root.careMode === "relaxed") ? 0.5 : 1.0;

            if (root.isSleeping) {
                // Energy recovers during sleep
                root.energy = Math.min(100.0, root.energy + 1.2);
                root.hunger = Math.max(0.0, root.hunger - 0.1 * decayMult);
            } else {
                // Gentle natural decay over hours
                root.hunger = Math.max(0.0, root.hunger - 0.18 * decayMult);
                root.energy = Math.max(0.0, root.energy - 0.12 * decayMult);
            }

            // Cleanliness drops very slowly
            root.cleanliness = Math.max(0.0, root.cleanliness - 0.08 * decayMult);

            // Happiness depends on hunger and cleanliness
            if (root.hunger < 25.0 || root.cleanliness < 25.0) {
                root.happiness = Math.max(10.0, root.happiness - 0.3 * decayMult);
            }

            root.requestSave();
        }
    }

    // ── Experience & Level Progression ────────────────────────────────────────
    function addXp(amount) {
        root.xp += amount;
        while (root.xp >= root.xpToNextLevel) {
            root.xp -= root.xpToNextLevel;
            root.level += 1;
            root.speechBubbleText = "Leveled up! " + root.petName + " reached Lv. " + root.level + "! 🎉";
            root.triggerParticle("sparkle");
        }
        root.requestSave();
    }

    // ── Interactive User Actions ──────────────────────────────────────────────

    // 1. Pet / Cuddle interaction (mouse click or touch)
    function pet() {
        if (root.isSleeping) {
            root.isSleeping = false;
        }
        root.currentState = "happy";
        root.happiness = Math.min(100.0, root.happiness + 6.0);
        root.triggerParticle("heart");
        root.triggerSpeech("petting");
        root.addXp(15);
        reactionTimeoutTimer.interval = 2400;
        reactionTimeoutTimer.restart();
    }

    // 2. Feed snack or food treat
    function feed(foodId) {
        var food = PetCatalog.getFood(foodId);
        if (!food) return;

        if (root.isSleeping) {
            root.isSleeping = false;
        }
        root.currentState = "eat";
        var isFav = (root.petData && root.petData.favoriteFood === food.id);
        var bonus = isFav ? food.favBonus : 0;
        root.hunger = Math.min(100.0, root.hunger + food.nutrition + bonus);
        root.happiness = Math.min(100.0, root.happiness + (isFav ? 8.0 : 3.0));

        root.triggerParticle("crumb");
        root.triggerSpeech("eating");
        root.addXp(isFav ? 30 : 20);

        reactionTimeoutTimer.interval = 2800;
        reactionTimeoutTimer.restart();
    }

    // 3. Play ball minigame
    function play() {
        if (root.isSleeping) {
            root.isSleeping = false;
        }
        root.currentState = "happy";
        root.happiness = Math.min(100.0, root.happiness + 12.0);
        root.energy = Math.max(5.0, root.energy - 6.0);
        root.triggerParticle("sparkle");
        root.speechBubbleText = "Caught the ball! What a toss! 🎾✨";
        root.addXp(35);

        // Pet runs towards the ball
        root.flipX = root.roamPosition > 0.5;
        root.roamPosition = 0.5;

        reactionTimeoutTimer.interval = 2600;
        reactionTimeoutTimer.restart();
    }

    // 4. Sleep / Wake toggle
    function toggleSleep() {
        root.isSleeping = !root.isSleeping;
        if (root.isSleeping) {
            root.currentState = "sleep";
            root.triggerParticle("zzz");
            root.speechBubbleText = "Zzz... Goodnight, taking a cozy nap~ 💤";
        } else {
            root.currentState = "idle";
            root.speechBubbleText = "*yawns and stretches* Good morning! ☀️";
        }
        root.requestSave();
    }

    // 5. Groom / Clean
    function groom() {
        root.cleanliness = 100.0;
        root.happiness = Math.min(100.0, root.happiness + 8.0);
        root.triggerParticle("sparkle");
        root.speechBubbleText = "All clean and sparkling! Squeaky clean! 🫧";
        root.addXp(20);
        root.currentState = "happy";
        reactionTimeoutTimer.interval = 2200;
        reactionTimeoutTimer.restart();
    }

    // 6. Switch Active Pet
    function selectPet(petId) {
        if (!PetCatalog.getPet(petId)) return;
        root.activePetId = petId;
        root.petData = PetCatalog.getPet(petId);
        root.petName = root.petData.name;
        root.petSpecies = root.petData.species;
        root.triggerSpeech("greetings");
        root.triggerParticle("sparkle");
        root.requestSave();
    }

    // 7. Equip Accessory
    function equipAccessory(accId) {
        root.activeAccessoryId = accId;
        root.triggerParticle("sparkle");
        root.requestSave();
    }

    // 8. Care Mode Cycle (Normal -> Relaxed -> Frozen -> Normal)
    function cycleCareMode() {
        if (root.careMode === "normal") root.careMode = "relaxed";
        else if (root.careMode === "relaxed") root.careMode = "frozen";
        else root.careMode = "normal";
        root.triggerParticle("sparkle");
        root.requestSave();
    }

    // 9. System Reactivity Toggles
    function toggleMusicReact() {
        root.reactToMusic = !root.reactToMusic;
        root.triggerParticle("sparkle");
        root.requestSave();
    }

    function toggleCpuReact() {
        root.reactToCpu = !root.reactToCpu;
        root.triggerParticle("sparkle");
        root.requestSave();
    }

    // 10. Custom Name Setter
    function setCustomName(newName) {
        root.customPetName = newName.trim();
        root.requestSave();
    }

    // 11. Reset Progression & Vitals
    function resetStats() {
        root.hunger = 85.0;
        root.happiness = 90.0;
        root.energy = 95.0;
        root.cleanliness = 100.0;
        root.level = 1;
        root.xp = 0;
        root.customPetName = "";
        root.triggerSpeech("greetings");
        root.triggerParticle("sparkle");
        root.requestSave();
    }
}
