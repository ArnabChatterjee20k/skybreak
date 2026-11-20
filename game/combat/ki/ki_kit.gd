class_name KiKit
extends Resource
## One legend's ki attacks (GAME_DESIGN §5.8, §6): tap blast (Q), charged blast
## (hold Q), beam special (1) and beam ultimate (4). Each move's frame data,
## damage and costs are a MoveData; the shot and beam shapes are here.

@export var blast: MoveData
@export var charged: MoveData
@export var beam: MoveData
@export var ultimate: MoveData
## Burst stocks the ultimate beam costs (§5.9).
@export var ultimate_burst_stocks: int = 2

@export_group("Blasts")
@export var blast_speed: float = 42.0
@export var blast_radius: float = 0.35
@export var blast_range: float = 60.0
## Turn rate toward the target in rad/s; 0 flies straight. Homing tap blasts beat sidesteps.
@export var blast_homing: float = 0.0
@export var charged_speed: float = 30.0
@export var charged_radius: float = 0.8
@export var charged_range: float = 60.0

@export_group("Beams")
@export var beam_radius: float = 0.9
## Furthest a beam reaches (m) and how fast its head travels there (m/s).
@export var beam_range: float = 55.0
@export var beam_speed: float = 120.0
## Side rays at +-this yaw (radians) beside the main ray; 0 for none (Lyra's split beam).
@export var beam_split_angle: float = 0.0
## Side ray radius as a share of beam_radius.
@export var beam_split_radius_share: float = 0.6
## Ultimate beam radius and range.
@export var ultimate_radius: float = 1.3
@export var ultimate_range: float = 70.0

@export_group("Look")
## Energy colour of this legend's shots and beams (view only).
@export var color: Color = Color(1.0, 0.6, 0.25)


func is_beam(move: MoveData) -> bool:
	return move != null and (move == beam or move == ultimate)


func radius_for(move: MoveData) -> float:
	return ultimate_radius if move == ultimate else beam_radius


func range_for(move: MoveData) -> float:
	return ultimate_range if move == ultimate else beam_range
