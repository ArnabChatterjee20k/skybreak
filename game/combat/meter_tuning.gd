class_name MeterTuning
extends Resource
## Every meter constant the sim uses that is the same for all fighters.
## Amounts are in display units; the sim stores meters in sixtieths, so a rate
## per second here is also the stored change per tick. Durations in ticks.

@export_group("Health")
## Share of each hit's damage, in percent, that turns grey and can regenerate.
@export var grey_percent: int = 40
## Grey health regained per second once regeneration starts.
@export var grey_regen_per_second: int = 150
## Ticks without being hit before grey health starts to regenerate.
@export var grey_regen_delay_ticks: int = 180
## Health in percent of max below which Last Stand gives its free burst.
@export var last_stand_health_percent: int = 15

@export_group("Ki")
## Most ki a fighter can hold.
@export var ki_max: int = 100
## Ki every fighter has when a round starts.
@export var round_start_ki: int = 50
## Ki gained per second at all times, except while charging.
@export var ki_passive_per_second: int = 2
## Ki gained per second while charging (replaces the passive gain).
@export var ki_charge_per_second: int = 25
## Ki the attacker gains for each hit that lands.
@export var ki_per_landed_hit: int = 3
## Ki gained for each blocked hit.
@export var ki_per_blocked_hit: int = 2
## Cost of a dash step.
@export var dash_ki_cost: int = 8
## Cost of a rush dash toward the lock-on target.
@export var rush_dash_ki_cost: int = 15
## Cost of a vanish step.
@export var vanish_step_ki_cost: int = 20
## Ki per second drained while a dash is sustained (0 = free; not in the design yet).
@export var sustained_dash_ki_per_second: int = 0

@export_group("Guard")
## Guard regained per second once regeneration starts.
@export var guard_regen_per_second: int = 20
## Ticks without blocking before guard starts to regenerate.
@export var guard_regen_delay_ticks: int = 60
## Ticks a fighter stays stunned after its guard breaks.
@export var guard_break_ticks: int = 60

@export_group("Burst")
## Burst in one stock.
@export var burst_stock_size: int = 100
## Most stocks a fighter can hold.
@export var burst_max_stocks: int = 3
## Burst gained per 1,000 damage dealt.
@export var burst_per_1000_damage_dealt: int = 10
## Burst gained per 1,000 damage taken.
@export var burst_per_1000_damage_taken: int = 15
## Burst gained for each perfect block.
@export var burst_per_perfect_block: int = 15
## Stocks Last Stand gives, once per match.
@export var last_stand_burst_stocks: int = 1
