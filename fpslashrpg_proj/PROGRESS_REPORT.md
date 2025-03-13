# First Person Slasher RPG - Progress Report

## Project Overview
This document tracks the development progress of the First Person Slasher RPG project.

## Current Features
- Basic player movement and camera controls
- Enemy AI with basic pathfinding
- Weapon system with morning star implementation
- First-person slasher mechanics with swing animations and hitbox detection
- Stamina system for attacks and sprinting
- Crosshair UI for aiming
- Stamina bar display in HUD
- Weapon type classification system (1h crush, 1h slash, 2h)
- Multiple attack animations per weapon type
- Debug UI with FPS counter (toggleable with F3)
- Impact particle effects for weapon hits on different surfaces

## Recent Changes

### 2025-03-13
- Created progress report document
- Enhanced weapon system to properly handle the morning star model:
  - Added detection for grip area to use as pivot/locator
  - Implemented proper hitbox detection for weapon collision
  - Created swing animations with easing functions for natural movement
- Added stamina system to player for sprinting and attacks
- Created dedicated morning star weapon scene with custom parameters
- Fixed weapon rotation and positioning to align with grip area
- Added weapon switching input actions (mouse wheel up/down or 1/2 keys)
- Implemented tracking of hit objects to prevent multiple hits in single swing
- Added methods to interact with objects in the game world
- Fixed type error in weapon.gd where a boolean was being incorrectly assigned to a Node3D variable
- Adjusted morning star weapon position in player scene to be closer to the camera
- Made hitbox collision objects invisible while maintaining functionality
- Fixed visibility issue with mgrip and hitbox geometry in the morning star model by making them invisible in the weapon script
- Added a crosshair UI to the center of the screen for better aiming
- Implemented attack functionality with left mouse button, including stamina cost
- Fixed bugs in attack system:
  - Corrected weapon reference path in player controller
  - Added debug output for attack actions
  - Prevented duplicate attack triggers from weapon and player controller
  - Improved swing animation for better visual feedback
- Added player HUD with stamina bar display:
  - Created a stamina bar that updates in real-time
  - Added visual feedback (red tint) for low stamina
  - Connected HUD to player signal system for responsive updates
- Enhanced weapon animation system:
  - Implemented weapon type classification (1h crush, 1h slash, 2h)
  - Created two distinct attack animations for 1h crush weapons:
    - "overhead_smash" - A powerful downward smashing motion
    - "side_swing" - A horizontal swing from left to right
  - Added random selection between attack animations for variety
  - Improved animation system to properly handle wind-up and follow-through
- Added debug UI functionality:
  - Implemented FPS counter in the top-left corner
  - Created toggleable debug interface (press F3 to toggle)
  - Set up system for easily adding more debug information in the future
- Implemented weapon impact particle system:
  - Created particle effects that spawn at the point of impact
  - Designed different particle effects based on surface material (metal, stone, wood, flesh)
  - Added precise impact point detection using raycasting
  - Implemented automatic cleanup of particle effects to prevent memory leaks
  - Made particles one-shot with proper orientation to the hit surface

## Technical Notes
- The morning star model uses "mgrip" node as the grip area and "hitbox" for collision detection
- The weapon system now properly positions weapons based on their grip area
- Hitbox detection is implemented through Area3D nodes that connect to collision signals
- The player scene has been updated to properly integrate the morning star weapon
- Left mouse button is mapped to the attack action in the input settings
- Attacking consumes stamina (25 points by default)
- The weapon system now supports different weapon types with unique animation sets
- Stamina display updates in real-time using signals from the player controller
- Debug UI can be toggled with the F3 key and is implemented through a modular system
- Impact particles are triggered in the weapon's hitbox collision handler and are automatically destroyed after playback
- Surface type detection for particles is based on object groups and naming conventions

## Next Steps
- Add more weapons with different attack patterns
- Implement enemy AI reactions to attacks
- Add damage indicators and hit effects
- Create UI for player health and stamina
- Implement inventory system for weapon management
