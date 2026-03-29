# 🎮 Indie Game Starter Kit (Godot)

Template base para criação rápida de jogos 2D com menu completo, settings, suporte a joystick e identidade visual consistente.

---

## 🎯 Objetivo

Este repositório serve como ponto de partida para novos projetos do estúdio, eliminando a necessidade de recriar:

- Menu inicial
- Sistema de pausa
- Settings (volume + fullscreen)
- Suporte a teclado e controle
- UI padronizada (botões, sons, fontes)

> 💡 Foco: começar novos jogos em minutos, não horas.

---

## 🚀 Features

- ✅ Main Menu (Start / Settings / Controls / Quit)
- ✅ Pause Menu funcional
- ✅ Settings:
  - Volume master
  - Fullscreen toggle
- ✅ Controles (teclado + joystick)
- ✅ Navegação completa por controle
- ✅ UI com:
  - Hover
  - Pressed
  - Focus
- ✅ Sons de interface (hover/click)
- ✅ Transições simples
- ✅ Estrutura de projeto organizada

---

## 📁 Estrutura do Projeto

'''bash
res://
├ core/
│ ├ managers/
│ │ ├ audio_manager.gd
│ │ ├ scene_manager.gd
│ │ └ config_manager.gd
│
├ scenes/
│ ├ main_menu/
│ │ ├ MainMenu.tscn
│ │ ├ SettingsPanel.tscn
│ │ ├ ControlsPanel.tscn
│ │
│ ├ game/
│ │ ├ Level.tscn
│ │ └ PauseMenu.tscn
│
├ ui/
│ ├ components/
│ ├ themes/
│
├ assets/
│ ├ fonts/
│ ├ icons/
│ ├ audio/
│ └ textures/
│
└ scripts/
'''