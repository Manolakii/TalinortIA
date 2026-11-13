class_name QualityPreset
extends Resource
## Un preset de calidad gráfica (bajo, medio, alto). Pensado para Remote Play:
## la compu del anfitrión dibuja y transmite a la vez.

@export var id: StringName
@export var display_name: String = ""

@export_group("Posprocesado")
@export var ssao: bool = true
@export var ssil: bool = true
@export var glow: bool = true
@export var fog: bool = true

@export_group("Sombras")
## Tamaño del atlas de sombras del sol (potencia de 2).
@export var shadow_atlas_size: int = 4096
## 0 = duras, 5 = las más suaves (RenderingServer.ShadowQuality).
@export_range(0, 5) var soft_shadow_quality: int = 3

@export_group("Escena")
## 0 a 1: proporción de briznas de pasto que se dibujan.
@export_range(0.0, 1.0) var grass_density: float = 1.0
## Escala de render 3D (1 = nativo).
@export_range(0.5, 1.0) var render_scale: float = 1.0
## 0 = sin MSAA, 1 = 2x, 2 = 4x (Viewport.MSAA).
@export_range(0, 2) var msaa_3d: int = 1
