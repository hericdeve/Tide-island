# 🐾 Tide Island — Pixel Pet Design Guide (24×24 High Resolution)

Welcome to the **Pixel Pet Extensibility System**! This guide walks you through designing, animating, and registering custom pets and accessories for your Tide Island notch companion.

---

## 🎨 1. The 24×24 ASCII Sprite Matrix

All pets are defined in `PetCatalog.js` using human-readable **24×24 string arrays**. Each character in the 24-row by 24-column grid maps directly to a color in the pet's palette:

| Character | Role | Purpose |
|---|---|---|
| `.` | Transparent | Empty space around your pet |
| `X` | Outline | Outer silhouette / shadow boundary |
| `1` | Primary Body | Main coat, fur, or scale color |
| `2` | Secondary Body | Chest, muzzle, belly, or inner ears |
| `3` | Shadow / Accent | Muscle shadows, tail rings, or darker coat patches |
| `4` | Highlight | Sheen, forehead glint, or top coat shine |
| `E` | Eyes | Pupil / Eye color |
| `W` | Eye Sparkle | Crisp eye shine or glint |
| `B` | Blush | Rosy cheek circles (soft pink) |
| `A` | Special Accent | Collars, horns, bells, sparks, or bows |

### Resolution-Agnostic Engine
The engine (`PixelSpriteView.qml`) dynamically measures grid dimensions:
```javascript
var gridH = frame.length;
var gridW = frame[0].length;
var p = Math.max(1, Math.floor(Math.min(width / gridW, height / gridH)));
```
- **Closed Notch Pill (`Minimum.qml`)**: 24×24 at 1× integer scale (24px) for razor-sharp micro-graphics.
- **Smartwatch Face (`Circle.qml`)**: 24×24 at 1× integer scale (24px) centered within the happiness progress ring.
- **Expanded Habitat (`Full.qml`)**: 24×24 at 2× integer scale (48px) with nearest-neighbor integer scaling.

---

## 🐾 2. Designing a New Pet

To add a new pet, open `qml/widgets/pixel_pet/PetCatalog.js` and add an entry to the `PETS` dictionary:

```javascript
"panda": {
    id: "panda",
    name: "Bao",
    species: "Giant Panda",
    bio: "A peaceful, bamboo-loving bear who rolls around happily.",
    favoriteFood: "carrot", // or "berry", "meal", etc.
    palette: {
        ".": "transparent",
        "X": "#111827",
        "1": "#f8fafc", // White body
        "2": "#1e293b", // Dark charcoal arms, ears, eye patches
        "3": "#cbd5e1", // Subtle shadow tone
        "4": "#ffffff", // Pure white highlight
        "E": "#0f172a", // Dark pupil
        "W": "#ffffff", // Eye gleam
        "B": "#fb7185", // Pink blush
        "A": "#10b981"  // Emerald bamboo leaf
    },
    frames: {
        idle: [ /* 2 frames (24x24): breathing or blinking */ ],
        walk: [ /* 2 frames (24x24): stepping feet */ ],
        happy: [ /* 1-2 frames (24x24): jumping or rolling */ ],
        sleep: [ /* 1 frame (24x24): sleeping curled up */ ],
        eat: [ /* 1 frame (24x24): chewing animation */ ],
        stressed: [ /* 1 frame (24x24): sweat drop or worried eyes */ ],
        jamming: [ /* 2 frames (24x24): head bobbing up and down */ ]
    }
}
```

### Standard Frame Invariants:
1. Every frame array must contain **exactly 24 rows**.
2. Every row must be **exactly 24 characters wide**.
3. For grounded animations (`idle`, `walk`, `eat`, `stressed`, `jamming`), keep feet resting on **row 22 or 23**.
4. For airborne animations (`happy`), pad empty rows at the bottom so the character floats off the ground.
5. For sleeping animations (`sleep`), keep the curled body resting near the bottom baseline.

---

## 🎩 3. Designing Custom Accessories

Accessories are **24×10 pixel overlays** positioned over the top of the pet's head. You can add hats, glasses, horns, or headwear to `ACCESSORIES`:

```javascript
"party": {
    id: "party",
    name: "Party Hat",
    icon: "󰍢",
    type: "hat",
    palette: {
        ".": "transparent",
        "X": "#1e1c24",
        "1": "#f43f5e",
        "2": "#38bdf8",
        "3": "#facc15"
    },
    frames: [
        [
            "...........XX...........",
            "..........X33X..........",
            ".........X1111X.........",
            "........X222222X........",
            ".......X11111111X.......",
            "......X2222222222X......",
            ".....X111111111111X.....",
            "...XXXXXXXXXXXXXXXXXX...",
            "........................",
            "........................"
        ]
    ]
}
```

---

## 🍎 4. Adding Custom Foods

Foods are registered in `FOODS` in `PetCatalog.js`:

```javascript
"bamboo": {
    id: "bamboo",
    name: "Fresh Bamboo",
    icon: "󰄛",
    nutrition: 35,
    favBonus: 15,
    crumbColor: "#10b981"
}
```

---

## 💡 Pro Tips for Pixel Art
1. **Integer Scaling**: All pixels render with `ctx.imageSmoothingEnabled = false` (nearest-neighbor), so your sprites will always look sharp and authentic on 4K, 1440p, or 1080p screens.
2. **Horizontal Flipping**: You only need to draw walking right! The engine automatically inverts `flipX` when the pet turns around to walk left.
3. **Head Bobbing**: In `jamming` state, frame 1 drops down 1 pixel to give that classic beat-bobbing feel; accessories follow the head bobbing automatically.
4. **Favorites**: When you feed a pet their `favoriteFood`, they earn extra bonus XP, extra happiness, and drop customized food crumbs!
