# 🎮 Godot Mini Game Template

![Godot](https://img.shields.io/badge/Godot-4.x-blue?logo=godot-engine)
![Status](https://img.shields.io/badge/status-active-success)
![License](https://img.shields.io/badge/license-MIT-green)

A clean, scalable and reusable **Godot template** designed to accelerate the creation of mini games.

> Build faster. Reuse more. Focus on gameplay.

---

## ✨ Why this template?

Creating a new game from scratch every time is inefficient.

This template gives you a **solid foundation** so you can:

- ⚡ Prototype faster
- 🧠 Focus on gameplay, not boilerplate
- 🔁 Reuse systems across multiple games
- 🧩 Keep your architecture clean and modular

---

## 🚀 Features

### 🖥️ Menu System
- Fully functional main menu
- Panel-based navigation (no scene swapping needed)
- Keyboard/controller friendly

---

### ⚙️ Settings Manager
- Fullscreen toggle  
- Resolution selector  
- Volume control  
- Language selection  
- Auto-save (`user://settings.cfg`)

---

### 🌐 Localization System
- Multi-language support (`pt_BR`, `en_US`)
- Key-based translations
- Real-time language switching
- Automatic UI updates

---

### 🎮 Controls System
- Centralized control definitions
- Data-driven (no hardcoding)
- Easily customizable per game

```gdscript
{"label_key": "controls_move_left", "value": "A / ←"}