# NeuroTrackerX — Guide d'installation Godot 4

## Structure du projet
```
neurotracker/
├── project.godot          ← Configuration principale
├── scenes/
│   ├── Menu.tscn          ← Scène du menu principal
│   └── GameScene.tscn     ← Scène de jeu 3D
├── scripts/
│   ├── GameManager.gd     ← Autoload : état global du jeu
│   ├── Ball.gd            ← Comportement des balles
│   ├── GameScene.gd       ← Logique principale des phases
│   └── Menu.gd            ← Logique du menu
```

## Installation

### 1. Prérequis
- Godot 4.2+ (télécharger sur https://godotengine.org)
- Fonctionne sur Raspberry Pi 4 avec Godot 4 ARM

### 2. Ouvrir le projet
1. Lancer Godot
2. "Import" → sélectionner le dossier `neurotracker/`
3. Ouvrir `project.godot`

### 3. Vérifier l'Autoload
Dans **Projet > Paramètres du projet > Autoload** :
- Vérifier que `GameManager` pointe vers `res://scripts/GameManager.gd`
- Si absent : cliquer "+", chemin = `res://scripts/GameManager.gd`, nom = `GameManager`

### 4. Lancer le jeu
- Appuyer sur **F5** ou le bouton ▶

---

## Phases de jeu

```
MÉMORISATION (3s)
  ↓ Les balles cibles sont surlignées en jaune vif + lumière pulsante
MOUVEMENT (5s)
  ↓ Toutes les balles deviennent identiques et bougent dans la boîte
ROTATION CAMÉRA (4s)
  ↓ La caméra tourne autour de la boîte — les balles sont immobiles
SÉLECTION
  ↓ L'utilisateur tape les balles + confirme
RÉSULTAT (3s)
  ↓ Vert = bonne balle, Rouge = mauvaise sélection
MANCHE SUIVANTE...
```

## Paramètres configurables (menu Options)
| Paramètre | Défaut | Description |
|-----------|--------|-------------|
| Nombre de balles | 8 | Total dans la boîte |
| Balles à mémoriser | 2 | Cibles à retenir |
| Durée mémorisation | 3s | Temps d'affichage des cibles |
| Durée mouvement | 5s | Temps de déplacement |
| Nombre de manches | 10 | Parties par session |

## Système de difficulté
- **Victoire** → vitesse +0.2 (max 3.0)
- **Défaite** → vitesse -0.15 (min 0.5)
- La vitesse est affichée en haut à gauche
- Score final = manches gagnées / total

## Optimisation Raspberry Pi 4
- Pas de shadows activées
- Glow léger (pas de SDFGI)
- Balles en SpheresMesh simples
- Résolution cible : 1280×720

## Contrôles tactiles
- **Tap sur une balle** → la sélectionne/désélectionne (en bleu)
- **Bouton CONFIRMER** → valide la sélection
- **Bouton PAUSE** → met le jeu en pause
- **Bouton ⬅ MENU** → retour au menu principal
