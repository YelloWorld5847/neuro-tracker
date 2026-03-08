# NeuroTrackerX

Jeu de mémoire visuelle 3D développé avec Godot 4.
Des balles de tennis rebondissent dans une boîte transparente — tu dois retenir lesquelles étaient surlignées au départ.

---

## Structure du projet

```
neurotracker/
├── project.godot
├── scenes/
│   ├── Menu.tscn
│   └── GameScene.tscn
├── scripts/
│   ├── GameManager.gd     (Autoload)
│   ├── Ball.gd
│   ├── GameScene.gd
│   └── Menu.gd
```

---

## Lancer le projet en dev

1. Godot 4.2+ — https://godotengine.org
2. Import → sélectionner le dossier `neurotracker/`
3. Vérifier dans **Projet > Paramètres > Autoload** que `GameManager` pointe vers `res://scripts/GameManager.gd`
4. F5 pour lancer

---

## Installer sur Raspberry Pi 4 avec écran tactile

C'est la config principale pour laquelle le jeu a été pensé.

### Ce qu'il faut

- Raspberry Pi 4 (2Go RAM minimum, 4Go recommandé)
- Raspberry Pi OS 64 bits (Bookworm de préférence)
- Écran tactile officiel 7" ou compatible DSI/HDMI
- Godot 4 ARM64 — télécharger le build Linux ARM64 sur godotengine.org

### Exporter depuis Godot

Dans **Projet > Exporter**, créer un export Linux avec ces paramètres :
- Architecture : `arm64`
- Intégrer PCK : coché
- S3TC BPTC : décoché
- ETC2 ASTC : coché
- Pré-calculateur de shader : coché (évite des freezes au premier lancement)

Avant d'exporter, activer ETC2/ASTC dans **Projet > Paramètres > Rendu > Textures**.

### Copier sur le Pi

```bash
scp NeuroTrackerX.arm64 pi@<ip_du_pi>:~/Desktop/
```

Ou clé USB, ça marche aussi.

### Premier lancement

```bash
chmod +x ~/Desktop/NeuroTrackerX.arm64
./Desktop/NeuroTrackerX.arm64
```

### Lancer automatiquement au démarrage

Créer le fichier suivant :

```
~/.config/autostart/neurotracker.desktop
```

Avec ce contenu :

```ini
[Desktop Entry]
Type=Application
Name=NeuroTrackerX
Exec=/home/pi/Desktop/NeuroTrackerX.arm64
```

Le jeu se lance tout seul après le boot, sans avoir à ouvrir un terminal.

### Écran tactile

Le jeu supporte nativement le tactile — tap sur une balle pour la sélectionner.
Si l'écran est à l'envers ou mal orienté, ajouter dans `/boot/config.txt` :

```
display_rotate=2
```

Pour un écran officiel Pi 7" branché en DSI, aucune config supplémentaire normalement.

### Paramètres sauvegardés

Les paramètres (nombre de balles, durée, etc.) sont sauvegardés dans :
```
~/.local/share/NeuroTrackerX/settings.cfg
```
Ils persistent entre les lancements, pas besoin de reconfigurer à chaque fois.

### Si les perfs sont mauvaises

Le jeu tourne en `forward_plus` par défaut. Si c'est trop lourd sur le Pi, changer dans `project.godot` :

```
renderer/rendering_method="gl_compatibility"
```

---

## Paramètres du jeu

| Paramètre | Défaut |
|-----------|--------|
| Nombre de balles | 8 |
| Balles à mémoriser | 2 |
| Durée mémorisation | 3s |
| Durée mouvement | 5s |
| Nombre de manches | 10 |

La vitesse augmente si tu gagnes (+0.2) et diminue si tu perds, proportionnellement aux erreurs. Min 0.5, max 3.0.