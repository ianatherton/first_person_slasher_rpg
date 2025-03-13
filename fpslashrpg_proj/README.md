# First Person Slasher RPG

A first-person slasher RPG game built with Godot 4.

## Project Structure

The project is organized as follows:

- `/scenes`: Contains game scenes (.tscn files)
  - `player.tscn`: Player character with first-person camera and weapon
  - `main_world.tscn`: Main game world with environment and player

- `/scripts`: Contains game scripts (.gd files)
  - `player_controller.gd`: Handles player movement and camera controls
  - `weapon.gd`: Handles weapon attacks and damage
  - `game_manager.gd`: Global game state management (autoloaded)
  - `input_setup.gd`: Sets up input mapping programmatically

- `/assets`: Contains game assets
  - `/models`: 3D models
  - `/textures`: Textures for 3D models
  - `/sounds`: Sound effects and music

## Controls

- **WASD**: Movement
- **Space**: Jump
- **Shift**: Sprint
- **Left Mouse Button**: Attack
- **Right Mouse Button**: Block (not implemented yet)
- **E**: Interact
- **I**: Inventory (not implemented yet)
- **1-3**: Weapon slots (not implemented yet)
- **Escape**: Toggle mouse capture

## How to Play

1. Open the project in Godot 4
2. Run the main scene (F5 or press the play button)
3. Move around using WASD and look around using the mouse
4. Attack with the left mouse button
5. Press Escape to free the mouse cursor

## Development Roadmap

- [ ] Add enemy AI
- [ ] Implement combat system with multiple weapons
- [ ] Add player stats and progression
- [ ] Create inventory system
- [ ] Add game UI (health, stamina, inventory)
- [ ] Add sound effects and music
- [ ] Implement save/load system
