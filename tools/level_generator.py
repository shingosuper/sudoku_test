#!/usr/bin/env python3
"""Offline hierarchical level generator for Color Queens.

Godot should only load finished JSON from ``data/levels.json``.  This script is
the production-side level factory:

1. Build a pool of legal king/crown placements for each board size.
2. For each placement, generate many colorings by difficulty tier.
3. Fill blank cells with connected regions using local entropy, seed distance,
   and color-distribution entropy.
4. Enforce at least two cells per region.
5. Canonicalize colorings by scanning left-to-right, top-to-bottom and encoding
   first-seen regions as a-z letters, then deduplicate per placement.
6. Keep only unique-solution, connected-region levels.
"""

from __future__ import annotations

import argparse
import json
import math
import random
import sys
from collections import Counter, deque
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


Cell = tuple[int, int]  # (row, col)
ORTHOGONAL: tuple[Cell, ...] = ((-1, 0), (0, 1), (1, 0), (0, -1))
EIGHT_WAY: tuple[Cell, ...] = (
    (-1, -1),
    (-1, 0),
    (-1, 1),
    (0, -1),
    (0, 1),
    (1, -1),
    (1, 0),
    (1, 1),
)
CANON_ALPHABET = "abcdefghijklmnopqrstuvwxyz"


DIFFICULTY_ALIASES = {
    "tutorial": "simple",
    "easy": "simple",
    "simple": "simple",
    "normal": "medium",
    "medium": "medium",
    "hard": "hard",
    "challenge": "challenge",
}


@dataclass(frozen=True)
class DifficultyPreset:
    score_min: int
    score_max: int
    compactness_weight: float
    local_entropy_weight: float
    distribution_entropy_weight: float
    distance_weight: float
    line_bias: float
    target_size_weight: float
    over_target_penalty: float
    fixed_pair_probability: float
    fixed_pair_count: int
    random_weight: float
    max_color_attempts: int
    require_fixed_pair: bool = False


@dataclass
class SolverMetrics:
    solution_count: int = 0
    search_nodes: int = 0
    branch_points: int = 0
    dead_ends: int = 0
    max_depth: int = 0


@dataclass(frozen=True)
class ShapeMetrics:
    boundary_edges: int
    min_region_size: int
    max_region_size: int
    singleton_regions: int
    two_cell_regions: int
    straight_line_regions: int
    average_local_entropy: float
    distribution_entropy: float
    connected: bool


@dataclass(frozen=True)
class LevelMetrics:
    solution_count: int
    difficulty_score: int
    search_nodes: int
    branch_points: int
    dead_ends: int
    max_depth: int
    boundary_edges: int
    min_region_size: int
    max_region_size: int
    singleton_regions: int
    two_cell_regions: int
    straight_line_regions: int
    average_local_entropy: float
    distribution_entropy: float
    connected: bool


PRESETS: dict[str, DifficultyPreset] = {
    "simple": DifficultyPreset(
        score_min=0,
        score_max=260,
        compactness_weight=3.0,
        local_entropy_weight=-3.2,
        distribution_entropy_weight=-1.0,
        distance_weight=2.4,
        line_bias=3.2,
        target_size_weight=2.2,
        over_target_penalty=9.0,
        fixed_pair_probability=0.92,
        fixed_pair_count=1,
        random_weight=0.35,
        max_color_attempts=700,
        require_fixed_pair=True,
    ),
    "medium": DifficultyPreset(
        score_min=190,
        score_max=560,
        compactness_weight=2.1,
        local_entropy_weight=-0.75,
        distribution_entropy_weight=0.25,
        distance_weight=1.55,
        line_bias=1.55,
        target_size_weight=1.45,
        over_target_penalty=5.5,
        fixed_pair_probability=0.52,
        fixed_pair_count=1,
        random_weight=0.9,
        max_color_attempts=900,
    ),
    "hard": DifficultyPreset(
        score_min=430,
        score_max=1050,
        compactness_weight=1.1,
        local_entropy_weight=1.25,
        distribution_entropy_weight=0.9,
        distance_weight=0.55,
        line_bias=0.2,
        target_size_weight=0.75,
        over_target_penalty=2.2,
        fixed_pair_probability=0.12,
        fixed_pair_count=1,
        random_weight=1.9,
        max_color_attempts=1200,
    ),
    "challenge": DifficultyPreset(
        score_min=760,
        score_max=2400,
        compactness_weight=0.45,
        local_entropy_weight=2.45,
        distribution_entropy_weight=1.35,
        distance_weight=-0.15,
        line_bias=-0.25,
        target_size_weight=0.35,
        over_target_penalty=0.8,
        fixed_pair_probability=0.0,
        fixed_pair_count=0,
        random_weight=3.0,
        max_color_attempts=1600,
    ),
}


def generate_level(
    level_id: int,
    size: int = 6,
    difficulty: str = "simple",
    seed: int | None = None,
    solution_pool_size: int = 512,
) -> dict[str, Any]:
    difficulty = normalize_difficulty(difficulty)
    if size < 5 or size > 9:
        raise ValueError("size should be in the supported range 5..9")

    rng = random.Random(seed)
    solution_pool = enumerate_king_solutions(size, solution_pool_size, rng)
    if not solution_pool:
        raise RuntimeError(f"unable to build a legal placement pool for {size}x{size}")

    seen_colorings: set[tuple[str, str]] = set()
    return generate_level_from_pool(level_id, size, difficulty, rng, solution_pool, seen_colorings, seed)


def generate_batch(
    start_id: int,
    specs: list[tuple[str, int, int]],
    seed: int | None = None,
    solution_pool_size: int = 512,
) -> list[dict[str, Any]]:
    levels: list[dict[str, Any]] = []
    next_id = start_id
    base_rng = random.Random(seed)

    solution_pools: dict[int, list[list[list[int]]]] = {}
    seen_by_size_solution: dict[tuple[int, str], set[str]] = {}

    for difficulty, size, count in specs:
        difficulty = normalize_difficulty(difficulty)
        if size not in solution_pools:
            pool_seed = base_rng.randrange(1, 2**31 - 1) if seed is not None else None
            solution_pools[size] = enumerate_king_solutions(size, solution_pool_size, random.Random(pool_seed))
            if not solution_pools[size]:
                raise RuntimeError(f"unable to build a legal placement pool for {size}x{size}")

        for _ in range(count):
            level_seed = base_rng.randrange(1, 2**31 - 1) if seed is not None else None
            level_rng = random.Random(level_seed)
            level = generate_level_from_pool(
                next_id,
                size,
                difficulty,
                level_rng,
                solution_pools[size],
                seen_by_size_solution,
                level_seed,
            )
            levels.append(level)
            next_id += 1
    return levels


def generate_level_from_pool(
    level_id: int,
    size: int,
    difficulty: str,
    rng: random.Random,
    solution_pool: list[list[list[int]]],
    seen_by_size_solution: dict[tuple[int, str], set[str]] | set[tuple[str, str]],
    seed: int | None = None,
) -> dict[str, Any]:
    preset = PRESETS[difficulty]
    best_level: dict[str, Any] | None = None
    best_distance = math.inf
    attempts = 0

    solution_order = solution_pool[:]
    rng.shuffle(solution_order)

    for solution in cycle_solutions(solution_order, rng, preset.max_color_attempts):
        solution_key = canonical_solution_key(solution)
        if isinstance(seen_by_size_solution, set):
            seen_colorings = seen_by_size_solution
        else:
            seen_colorings = seen_by_size_solution.setdefault((size, solution_key), set())

        for _ in range(max(1, preset.max_color_attempts // max(1, len(solution_order)))):
            attempts += 1
            regions = color_regions(size, solution, difficulty, rng)
            if regions is None:
                continue

            level = build_level(level_id, size, difficulty, solution, regions)
            repair_until_unique(level, solution, rng, max_repairs=size * size * 3)
            canonical = canonical_region_string(level["regions"])
            if isinstance(seen_by_size_solution, set):
                dedupe_key = (solution_key, canonical)
                if dedupe_key in seen_by_size_solution:
                    continue
                seen_by_size_solution.add(dedupe_key)
            else:
                if canonical in seen_colorings:
                    continue
                seen_colorings.add(canonical)

            metrics = analyze_level(level)
            if not is_valid_generated_level(metrics, preset):
                continue

            level["generator"] = generator_metadata(
                difficulty=difficulty,
                seed=seed,
                attempts=attempts,
                solution_pool_size=len(solution_pool),
                solution_key=solution_key,
                canonical_coloring=canonical,
                metrics=metrics,
                preset=preset,
            )

            distance = score_distance(metrics, preset)
            if distance < best_distance:
                best_distance = distance
                best_level = level

            if metrics_match(metrics, preset):
                return level

            if attempts >= preset.max_color_attempts:
                break

        if attempts >= preset.max_color_attempts:
            break

    if best_level is None:
        raise RuntimeError(f"unable to generate a unique {difficulty} {size}x{size} level")
    return best_level


def enumerate_king_solutions(size: int, cap: int, rng: random.Random) -> list[list[list[int]]]:
    """Enumerate many legal placements.

    A legal placement contains exactly one piece in every row and column, and no
    two pieces touch in the king's eight-neighborhood.  With one piece per row,
    only adjacent rows need to be checked for king adjacency.
    """

    solutions: list[list[list[int]]] = []
    used_cols: set[int] = set()
    cols_by_row: list[int] = []
    column_orders = [list(range(size)) for _ in range(size)]
    for columns in column_orders:
        rng.shuffle(columns)

    def search(row: int) -> None:
        if len(solutions) >= cap:
            return
        if row == size:
            solutions.append([[solution_row, col] for solution_row, col in enumerate(cols_by_row)])
            return
        for col in column_orders[row]:
            if col in used_cols:
                continue
            if row > 0 and abs(cols_by_row[row - 1] - col) <= 1:
                continue
            used_cols.add(col)
            cols_by_row.append(col)
            search(row + 1)
            cols_by_row.pop()
            used_cols.remove(col)

    search(0)
    rng.shuffle(solutions)
    return solutions


def cycle_solutions(
    solutions: list[list[list[int]]],
    rng: random.Random,
    max_attempts: int,
) -> Iterable[list[list[int]]]:
    if not solutions:
        return
    emitted = 0
    while emitted < max_attempts:
        shuffled = solutions[:]
        rng.shuffle(shuffled)
        for solution in shuffled:
            if emitted >= max_attempts:
                return
            emitted += 1
            yield solution


def color_regions(
    size: int,
    solution: list[list[int]],
    difficulty: str,
    rng: random.Random,
) -> list[list[int]] | None:
    preset = PRESETS[difficulty]
    region_count = len(solution)
    seed_positions = {region_id: tuple(solution[region_id - 1]) for region_id in range(1, region_count + 1)}
    regions = [[0 for _ in range(size)] for _ in range(size)]
    region_sizes = {region_id: 0 for region_id in range(1, region_count + 1)}

    for region_id, (row, col) in seed_positions.items():
        regions[row][col] = region_id
        region_sizes[region_id] = 1

    fixed_regions = choose_fixed_pair_regions(region_count, preset, rng)
    if not initialize_fixed_pair_regions(regions, seed_positions, region_sizes, fixed_regions, rng):
        return None

    target_sizes = build_region_target_sizes(size, region_count, fixed_regions, rng)

    remaining = size * size - sum(region_sizes.values())
    guard = size * size * region_count * 8
    while remaining > 0 and guard > 0:
        guard -= 1
        picked = pick_region_growth(
            regions=regions,
            seed_positions=seed_positions,
            region_sizes=region_sizes,
            target_sizes=target_sizes,
            fixed_regions=fixed_regions,
            rng=rng,
            preset=preset,
        )
        if picked is None:
            return None
        row, col, region_id = picked
        regions[row][col] = region_id
        region_sizes[region_id] += 1
        remaining -= 1

    if remaining != 0:
        return None
    if min(region_sizes.values()) < 2:
        return None
    if any(not is_region_connected(regions, region_id) for region_id in region_sizes):
        return None
    return regions


def choose_fixed_pair_regions(region_count: int, preset: DifficultyPreset, rng: random.Random) -> set[int]:
    if preset.fixed_pair_count <= 0 or rng.random() > preset.fixed_pair_probability:
        return set()
    ids = list(range(1, region_count + 1))
    rng.shuffle(ids)
    return set(ids[: min(preset.fixed_pair_count, region_count - 1)])


def initialize_fixed_pair_regions(
    regions: list[list[int]],
    seed_positions: dict[int, Cell],
    region_sizes: dict[int, int],
    fixed_regions: set[int],
    rng: random.Random,
) -> bool:
    if not fixed_regions:
        return True
    size = len(regions)
    for region_id in fixed_regions:
        seed = seed_positions[region_id]
        candidates = [
            neighbor
            for neighbor in shuffled_neighbors(seed, ORTHOGONAL, rng)
            if in_bounds(neighbor, size) and regions[neighbor[0]][neighbor[1]] == 0
        ]
        if not candidates:
            return False
        row, col = candidates[0]
        regions[row][col] = region_id
        region_sizes[region_id] += 1
    return True


def build_region_target_sizes(
    size: int,
    region_count: int,
    fixed_regions: set[int],
    rng: random.Random,
) -> dict[int, int]:
    min_size = 2
    target_sizes = {
        region_id: (2 if region_id in fixed_regions else min_size)
        for region_id in range(1, region_count + 1)
    }
    remaining = size * size - sum(target_sizes.values())
    growable = [region_id for region_id in target_sizes if region_id not in fixed_regions]
    if remaining < 0 or not growable:
        return target_sizes

    base_add = remaining // len(growable)
    extra = remaining % len(growable)
    rng.shuffle(growable)
    for index, region_id in enumerate(growable):
        target_sizes[region_id] += base_add
        if index < extra:
            target_sizes[region_id] += 1
    return target_sizes


def pick_region_growth(
    regions: list[list[int]],
    seed_positions: dict[int, Cell],
    region_sizes: dict[int, int],
    target_sizes: dict[int, int],
    fixed_regions: set[int],
    rng: random.Random,
    preset: DifficultyPreset,
) -> tuple[int, int, int] | None:
    best: tuple[int, int, int] | None = None
    best_score = -math.inf
    size = len(regions)

    for row in range(size):
        for col in range(size):
            if regions[row][col] != 0:
                continue
            pos = (row, col)
            for region_id in neighbor_region_ids(regions, pos):
                if region_id in fixed_regions and region_sizes[region_id] >= 2:
                    continue

                seed = seed_positions[region_id]
                same_neighbors = same_neighbor_count(regions, pos, region_id)
                local_entropy = neighborhood_entropy(regions, pos)
                next_distribution_entropy = distribution_entropy_after(region_sizes, region_id)
                distance = normalized_manhattan_distance(pos, seed, size)
                target_size = target_sizes[region_id]
                next_size = region_sizes[region_id] + 1
                size_pressure = (target_size - region_sizes[region_id]) / max(1, target_size)
                over_target = max(0, next_size - target_size)
                axis_aligned = row == seed[0] or col == seed[1]

                score = (
                    same_neighbors * preset.compactness_weight
                    + local_entropy * preset.local_entropy_weight
                    + next_distribution_entropy * preset.distribution_entropy_weight
                    - distance * preset.distance_weight
                    + size_pressure * preset.target_size_weight
                    + (preset.line_bias if axis_aligned else 0.0)
                    - over_target * preset.over_target_penalty
                    + rng.uniform(0.0, preset.random_weight)
                )
                if score > best_score:
                    best_score = score
                    best = (row, col, region_id)
    return best


def analyze_level(level: dict[str, Any]) -> LevelMetrics:
    solver = solve_metrics(level, limit=2)
    shape = shape_metrics(level)
    rows = int(level["rows"])
    easy_affordance = shape.two_cell_regions * 18 + shape.straight_line_regions * 5
    entropy_complexity = int(shape.average_local_entropy * 55 + shape.distribution_entropy * 28)
    score = (
        solver.search_nodes
        + solver.branch_points * 8
        + solver.dead_ends * 3
        + shape.boundary_edges * 2
        + entropy_complexity
        + shape.singleton_regions * 30
        + max(0, rows - 5) * 45
        - easy_affordance
    )
    score = max(0, score)
    if not shape.connected:
        score += 350

    return LevelMetrics(
        solution_count=solver.solution_count,
        difficulty_score=score,
        search_nodes=solver.search_nodes,
        branch_points=solver.branch_points,
        dead_ends=solver.dead_ends,
        max_depth=solver.max_depth,
        boundary_edges=shape.boundary_edges,
        min_region_size=shape.min_region_size,
        max_region_size=shape.max_region_size,
        singleton_regions=shape.singleton_regions,
        two_cell_regions=shape.two_cell_regions,
        straight_line_regions=shape.straight_line_regions,
        average_local_entropy=shape.average_local_entropy,
        distribution_entropy=shape.distribution_entropy,
        connected=shape.connected,
    )


def solve_metrics(level: dict[str, Any], limit: int = 2) -> SolverMetrics:
    metrics = SolverMetrics()
    rows = int(level["rows"])
    assigned_rows: set[int] = set()
    used_cols: set[int] = set()
    used_regions: set[int] = set()
    placed_by_row: dict[int, int] = {}

    def search(depth: int) -> None:
        if metrics.solution_count >= limit:
            return
        metrics.search_nodes += 1
        metrics.max_depth = max(metrics.max_depth, depth)

        if depth == rows:
            if len(used_regions) == int(level["targetCount"]):
                metrics.solution_count += 1
            return

        next_row = -1
        next_options: list[int] = []
        for row in range(rows):
            if row in assigned_rows:
                continue
            options = valid_options_for_row(level, row, used_cols, used_regions, placed_by_row)
            if not options:
                metrics.dead_ends += 1
                return
            if next_row < 0 or len(options) < len(next_options):
                next_row = row
                next_options = options

        if len(next_options) > 1:
            metrics.branch_points += 1

        assigned_rows.add(next_row)
        for col in next_options:
            if metrics.solution_count >= limit:
                break
            region_id = int(level["regions"][next_row][col])
            used_cols.add(col)
            used_regions.add(region_id)
            placed_by_row[next_row] = col
            search(depth + 1)
            del placed_by_row[next_row]
            used_regions.remove(region_id)
            used_cols.remove(col)
        assigned_rows.remove(next_row)

    search(0)
    return metrics


def find_solutions(level: dict[str, Any], limit: int = 2) -> list[list[list[int]]]:
    rows = int(level["rows"])
    assigned_rows: set[int] = set()
    used_cols: set[int] = set()
    used_regions: set[int] = set()
    placed_by_row: dict[int, int] = {}
    solutions: list[list[list[int]]] = []

    def search(depth: int) -> None:
        if len(solutions) >= limit:
            return
        if depth == rows:
            if len(used_regions) == int(level["targetCount"]):
                solutions.append([[row, placed_by_row[row]] for row in range(rows)])
            return

        next_row = -1
        next_options: list[int] = []
        for row in range(rows):
            if row in assigned_rows:
                continue
            options = valid_options_for_row(level, row, used_cols, used_regions, placed_by_row)
            if not options:
                return
            if next_row < 0 or len(options) < len(next_options):
                next_row = row
                next_options = options

        assigned_rows.add(next_row)
        for col in next_options:
            if len(solutions) >= limit:
                break
            region_id = int(level["regions"][next_row][col])
            used_cols.add(col)
            used_regions.add(region_id)
            placed_by_row[next_row] = col
            search(depth + 1)
            del placed_by_row[next_row]
            used_regions.remove(region_id)
            used_cols.remove(col)
        assigned_rows.remove(next_row)

    search(0)
    return solutions


def valid_options_for_row(
    level: dict[str, Any],
    row: int,
    used_cols: set[int],
    used_regions: set[int],
    placed_by_row: dict[int, int],
) -> list[int]:
    options: list[int] = []
    for col in range(int(level["cols"])):
        if col in used_cols:
            continue
        region_id = int(level["regions"][row][col])
        if region_id in used_regions:
            continue
        if is_adjacent_to_placed((row, col), placed_by_row):
            continue
        options.append(col)
    return options


def is_adjacent_to_placed(candidate: Cell, placed_by_row: dict[int, int]) -> bool:
    row, col = candidate
    for placed_row, placed_col in placed_by_row.items():
        if abs(row - placed_row) <= 1 and abs(col - placed_col) <= 1:
            return True
    return False


def build_level(
    level_id: int,
    size: int,
    difficulty: str,
    solution: list[list[int]],
    regions: list[list[int]],
) -> dict[str, Any]:
    return {
        "levelId": level_id,
        "name": f"{difficulty.capitalize()} {size}x{size}",
        "rows": size,
        "cols": size,
        "targetCount": size,
        "difficulty": difficulty,
        "tutorial": "自动生成关卡：每行、每列、每个颜色区域各一个皇冠，且皇冠不能相邻。",
        "regions": regions,
        "solution": solution,
    }


def repair_until_unique(
    level: dict[str, Any],
    target_solution: list[list[int]],
    rng: random.Random,
    max_repairs: int,
) -> None:
    """Eliminate alternative solutions by local region reassignment.

    The coloring stage creates connected regions from seeds, but especially on
    5x5 boards it often leaves multiple valid king placements.  This repair
    pass finds alternative solutions and moves one non-target cell from that
    alternative into an adjacent region already used by the alternative.  That
    makes the alternative violate the one-piece-per-region rule.
    """

    for _ in range(max_repairs):
        solutions = find_solutions(level, limit=6)
        if len(solutions) <= 1:
            return

        alternatives = [solution for solution in solutions if not same_solution(solution, target_solution)]
        if not alternatives:
            return

        rng.shuffle(alternatives)
        repaired = False
        for alternative in alternatives:
            if break_alternative_solution(level, alternative, target_solution, rng):
                repaired = True
                break
        if not repaired:
            return


def break_alternative_solution(
    level: dict[str, Any],
    alternative: list[list[int]],
    target_solution: list[list[int]],
    rng: random.Random,
) -> bool:
    regions = level["regions"]
    target_cells = {tuple(cell) for cell in target_solution}
    alt_positions = [(row, col) for row, col in alternative]
    rng.shuffle(alt_positions)

    for pos in alt_positions:
        if pos in target_cells:
            continue
        row, col = pos
        from_region = int(regions[row][col])
        if not can_remove_cell_from_region(regions, pos, from_region):
            continue

        candidate_regions = region_ids_from_solution(level, alternative)
        rng.shuffle(candidate_regions)
        for to_region in candidate_regions:
            if to_region == from_region:
                continue
            if not has_neighbor_region(regions, pos, to_region):
                continue
            regions[row][col] = to_region
            if is_region_connected(regions, from_region) and is_region_connected(regions, to_region):
                return True
            regions[row][col] = from_region
    return False


def shape_metrics(level: dict[str, Any]) -> ShapeMetrics:
    regions = level["regions"]
    rows = int(level["rows"])
    cols = int(level["cols"])
    sizes: Counter[int] = Counter()
    boundary_edges = 0

    for row in range(rows):
        for col in range(cols):
            region_id = int(regions[row][col])
            sizes[region_id] += 1
            if col + 1 < cols and int(regions[row][col + 1]) != region_id:
                boundary_edges += 1
            if row + 1 < rows and int(regions[row + 1][col]) != region_id:
                boundary_edges += 1

    if not sizes:
        return ShapeMetrics(0, 0, 0, 0, 0, 0, 0.0, 0.0, False)

    values = list(sizes.values())
    connected = all(is_region_connected(regions, region_id) for region_id in sizes)
    two_cell_regions = sum(1 for value in values if value == 2)
    straight_line_regions = sum(1 for region_id in sizes if is_straight_line_region(regions, region_id))
    local_entropy_values = [
        neighborhood_entropy(regions, (row, col))
        for row in range(rows)
        for col in range(cols)
    ]
    average_local_entropy = sum(local_entropy_values) / len(local_entropy_values)
    distribution_entropy = entropy_from_counts(values)

    return ShapeMetrics(
        boundary_edges=boundary_edges,
        min_region_size=min(values),
        max_region_size=max(values),
        singleton_regions=sum(1 for value in values if value == 1),
        two_cell_regions=two_cell_regions,
        straight_line_regions=straight_line_regions,
        average_local_entropy=average_local_entropy,
        distribution_entropy=distribution_entropy,
        connected=connected,
    )


def validate_level(level: dict[str, Any]) -> list[str]:
    errors: list[str] = []
    rows = int(level.get("rows", 0))
    cols = int(level.get("cols", 0))
    target_count = int(level.get("targetCount", 0))
    regions = level.get("regions", [])
    solution = level.get("solution", [])

    if rows <= 0 or cols <= 0:
        errors.append("dimensions must be positive")
    if len(regions) != rows:
        errors.append("region row count mismatch")
    if any(len(row) != cols for row in regions):
        errors.append("region column count mismatch")
    if len(solution) != target_count:
        errors.append("solution size does not match targetCount")

    region_sizes = Counter(
        int(regions[row][col])
        for row in range(rows)
        for col in range(cols)
    ) if regions and not errors else Counter()
    if region_sizes and min(region_sizes.values()) < 2:
        errors.append("each color region must contain at least two cells")

    seen_rows: set[int] = set()
    seen_cols: set[int] = set()
    seen_regions: set[int] = set()
    positions: list[Cell] = []
    for coordinate in solution:
        row, col = int(coordinate[0]), int(coordinate[1])
        if row < 0 or row >= rows or col < 0 or col >= cols:
            errors.append(f"solution coordinate out of bounds: {coordinate}")
            continue
        region_id = int(regions[row][col])
        if row in seen_rows:
            errors.append(f"duplicate solution row: {row}")
        if col in seen_cols:
            errors.append(f"duplicate solution column: {col}")
        if region_id in seen_regions:
            errors.append(f"duplicate solution region: {region_id}")
        seen_rows.add(row)
        seen_cols.add(col)
        seen_regions.add(region_id)
        positions.append((row, col))

    for index, a in enumerate(positions):
        for b in positions[index + 1 :]:
            if abs(a[0] - b[0]) <= 1 and abs(a[1] - b[1]) <= 1:
                errors.append(f"adjacent solution cells: {a} and {b}")

    metrics = analyze_level(level) if not errors else None
    if metrics is not None:
        if metrics.solution_count != 1:
            errors.append(f"expected unique solution, found {metrics.solution_count}")
        if not metrics.connected:
            errors.append("one or more regions are not connected")
    return errors


def generator_metadata(
    difficulty: str,
    seed: int | None,
    attempts: int,
    solution_pool_size: int,
    solution_key: str,
    canonical_coloring: str,
    metrics: LevelMetrics,
    preset: DifficultyPreset,
) -> dict[str, Any]:
    return {
        "version": 2,
        "strategy": "solution-pool+entropy-coloring+canonical-dedupe",
        "difficulty": difficulty,
        "seed": seed,
        "attempt": attempts,
        "solutionPoolSize": solution_pool_size,
        "solutionKey": solution_key,
        "canonicalColoring": canonical_coloring,
        "score": metrics.difficulty_score,
        "matchedPreset": metrics_match(metrics, preset),
        "searchNodes": metrics.search_nodes,
        "branchPoints": metrics.branch_points,
        "deadEnds": metrics.dead_ends,
        "boundaryEdges": metrics.boundary_edges,
        "minRegionSize": metrics.min_region_size,
        "twoCellRegions": metrics.two_cell_regions,
        "straightLineRegions": metrics.straight_line_regions,
        "averageLocalEntropy": round(metrics.average_local_entropy, 4),
        "distributionEntropy": round(metrics.distribution_entropy, 4),
    }


def is_valid_generated_level(metrics: LevelMetrics, preset: DifficultyPreset) -> bool:
    if metrics.solution_count != 1:
        return False
    if not metrics.connected:
        return False
    if metrics.min_region_size < 2:
        return False
    if preset.require_fixed_pair and metrics.two_cell_regions < 1:
        return False
    return True


def metrics_match(metrics: LevelMetrics, preset: DifficultyPreset) -> bool:
    return is_valid_generated_level(metrics, preset) and preset.score_min <= metrics.difficulty_score <= preset.score_max


def score_distance(metrics: LevelMetrics, preset: DifficultyPreset) -> float:
    if not is_valid_generated_level(metrics, preset):
        return math.inf
    if metrics.difficulty_score < preset.score_min:
        return preset.score_min - metrics.difficulty_score
    if metrics.difficulty_score > preset.score_max:
        return metrics.difficulty_score - preset.score_max
    return 0.0


def canonical_solution_key(solution: list[list[int]]) -> str:
    return ",".join(str(int(col)) for _, col in sorted(solution))


def canonical_region_string(regions: list[list[int]]) -> str:
    mapping: dict[int, str] = {}
    next_index = 0
    rows: list[str] = []
    for row in regions:
        encoded_row: list[str] = []
        for raw_region_id in row:
            region_id = int(raw_region_id)
            if region_id not in mapping:
                if next_index >= len(CANON_ALPHABET):
                    raise ValueError("canonical encoding supports at most 26 regions")
                mapping[region_id] = CANON_ALPHABET[next_index]
                next_index += 1
            encoded_row.append(mapping[region_id])
        rows.append("".join(encoded_row))
    return "/".join(rows)


def normalize_difficulty(difficulty: str) -> str:
    key = difficulty.strip().lower()
    if key not in DIFFICULTY_ALIASES:
        allowed = ", ".join(sorted(DIFFICULTY_ALIASES))
        raise ValueError(f"unknown difficulty '{difficulty}', expected one of: {allowed}")
    return DIFFICULTY_ALIASES[key]


def in_bounds(pos: Cell, size: int) -> bool:
    row, col = pos
    return 0 <= row < size and 0 <= col < size


def shuffled_neighbors(pos: Cell, offsets: tuple[Cell, ...], rng: random.Random) -> list[Cell]:
    row, col = pos
    result = [(row + row_delta, col + col_delta) for row_delta, col_delta in offsets]
    rng.shuffle(result)
    return result


def orthogonal_neighbors(pos: Cell) -> Iterable[Cell]:
    row, col = pos
    for row_delta, col_delta in ORTHOGONAL:
        yield row + row_delta, col + col_delta


def eight_way_neighbors(pos: Cell) -> Iterable[Cell]:
    row, col = pos
    for row_delta, col_delta in EIGHT_WAY:
        yield row + row_delta, col + col_delta


def neighbor_region_ids(regions: list[list[int]], pos: Cell) -> list[int]:
    result: list[int] = []
    size = len(regions)
    for row, col in orthogonal_neighbors(pos):
        if not in_bounds((row, col), size):
            continue
        region_id = int(regions[row][col])
        if region_id and region_id not in result:
            result.append(region_id)
    return result


def same_neighbor_count(regions: list[list[int]], pos: Cell, region_id: int) -> int:
    size = len(regions)
    result = 0
    for row, col in orthogonal_neighbors(pos):
        if in_bounds((row, col), size) and int(regions[row][col]) == region_id:
            result += 1
    return result


def neighborhood_entropy(regions: list[list[int]], pos: Cell) -> float:
    size = len(regions)
    counts: Counter[int] = Counter()
    for row, col in eight_way_neighbors(pos):
        if not in_bounds((row, col), size):
            continue
        region_id = int(regions[row][col])
        if region_id:
            counts[region_id] += 1
    return entropy_from_counts(counts.values())


def distribution_entropy_after(region_sizes: dict[int, int], grown_region_id: int) -> float:
    counts = []
    for region_id, size in region_sizes.items():
        counts.append(size + 1 if region_id == grown_region_id else size)
    return entropy_from_counts(counts)


def entropy_from_counts(counts: Iterable[int]) -> float:
    values = [count for count in counts if count > 0]
    if len(values) <= 1:
        return 0.0
    total = float(sum(values))
    entropy = 0.0
    for count in values:
        probability = count / total
        entropy -= probability * math.log(probability)
    return entropy / math.log(len(values))


def normalized_manhattan_distance(pos: Cell, seed: Cell, size: int) -> float:
    max_distance = max(1, (size - 1) * 2)
    return (abs(pos[0] - seed[0]) + abs(pos[1] - seed[1])) / max_distance


def is_region_connected(regions: list[list[int]], region_id: int) -> bool:
    cells = cells_for_region(regions, region_id)
    if not cells:
        return False
    lookup = set(cells)
    visited = {cells[0]}
    queue: deque[Cell] = deque([cells[0]])
    while queue:
        current = queue.popleft()
        for neighbor in orthogonal_neighbors(current):
            if neighbor in lookup and neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    return len(visited) == len(cells)


def can_remove_cell_from_region(regions: list[list[int]], pos: Cell, region_id: int) -> bool:
    cells = [cell for cell in cells_for_region(regions, region_id) if cell != pos]
    if len(cells) < 2:
        return False
    lookup = set(cells)
    visited = {cells[0]}
    queue: deque[Cell] = deque([cells[0]])
    while queue:
        current = queue.popleft()
        for neighbor in orthogonal_neighbors(current):
            if neighbor in lookup and neighbor not in visited:
                visited.add(neighbor)
                queue.append(neighbor)
    return len(visited) == len(cells)


def is_straight_line_region(regions: list[list[int]], region_id: int) -> bool:
    cells = cells_for_region(regions, region_id)
    if len(cells) < 2:
        return False
    rows = {row for row, _ in cells}
    cols = {col for _, col in cells}
    return len(rows) == 1 or len(cols) == 1


def cells_for_region(regions: list[list[int]], region_id: int) -> list[Cell]:
    return [
        (row, col)
        for row in range(len(regions))
        for col in range(len(regions[row]))
        if int(regions[row][col]) == region_id
    ]


def has_neighbor_region(regions: list[list[int]], pos: Cell, region_id: int) -> bool:
    return region_id in neighbor_region_ids(regions, pos)


def region_ids_from_solution(level: dict[str, Any], solution: list[list[int]]) -> list[int]:
    regions = level["regions"]
    result: list[int] = []
    for row, col in solution:
        region_id = int(regions[row][col])
        if region_id not in result:
            result.append(region_id)
    return result


def same_solution(a: list[list[int]], b: list[list[int]]) -> bool:
    return {int(row): int(col) for row, col in a} == {int(row): int(col) for row, col in b}


def load_level_file(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as file:
        data = json.load(file)
    if not isinstance(data, dict) or "levels" not in data or not isinstance(data["levels"], list):
        raise ValueError(f"{path} must contain a top-level 'levels' array")
    return data


def write_level_file(path: Path | None, data: dict[str, Any], indent: int = 2) -> None:
    text = json.dumps(data, ensure_ascii=False, indent=indent)
    if path is None:
        print(text)
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text + "\n", encoding="utf-8")


def max_level_id(levels: list[dict[str, Any]]) -> int:
    if not levels:
        return 0
    return max(int(level.get("levelId", 0)) for level in levels)


def parse_plan(
    plan: str | None,
    fallback_difficulty: str,
    fallback_size: int,
    fallback_count: int,
) -> list[tuple[str, int, int]]:
    if not plan:
        return [(normalize_difficulty(fallback_difficulty), fallback_size, fallback_count)]

    specs: list[tuple[str, int, int]] = []
    for item in plan.split(","):
        item = item.strip()
        if not item:
            continue
        if ":" not in item:
            raise ValueError("plan items must look like simple@5:10 or challenge@9:3")
        left, count_text = item.split(":", 1)
        if "@" in left:
            difficulty, size_text = left.split("@", 1)
            size = int(size_text)
        else:
            difficulty = left
            size = fallback_size
        specs.append((normalize_difficulty(difficulty), size, int(count_text)))
    return specs


def command_generate(args: argparse.Namespace) -> int:
    base_data: dict[str, Any] = {"levels": []}
    if args.append_from:
        base_data = load_level_file(Path(args.append_from))

    start_id = args.start_id
    if start_id is None:
        start_id = max_level_id(base_data["levels"]) + 1

    specs = parse_plan(args.plan, args.difficulty, args.size, args.count)
    generated = generate_batch(start_id, specs, args.seed, args.solution_pool)
    output_data = {
        "levels": [*base_data["levels"], *generated],
        "metadata": {
            "generatedBy": "tools/level_generator.py",
            "generatedCount": len(generated),
            "seed": args.seed,
            "solutionPool": args.solution_pool,
            "plan": args.plan or f"{normalize_difficulty(args.difficulty)}@{args.size}:{args.count}",
        },
    }

    output_path = None if args.output == "-" else Path(args.output)
    write_level_file(output_path, output_data, indent=args.indent)
    print_generation_summary(generated, file=sys.stderr)
    return 0


def command_analyze(args: argparse.Namespace) -> int:
    data = load_level_file(Path(args.input))
    rows: list[tuple[Any, ...]] = []
    has_errors = False
    for level in data["levels"]:
        metrics = analyze_level(level)
        rows.append(
            (
                int(level.get("levelId", 0)),
                str(level.get("name", "")),
                f"{int(level['rows'])}x{int(level['cols'])}",
                str(level.get("difficulty", "-")),
                metrics.solution_count,
                metrics.difficulty_score,
                metrics.search_nodes,
                metrics.branch_points,
                metrics.dead_ends,
                metrics.boundary_edges,
                metrics.min_region_size,
                metrics.two_cell_regions,
                metrics.straight_line_regions,
                f"{metrics.average_local_entropy:.2f}",
                f"{metrics.distribution_entropy:.2f}",
                "yes" if metrics.connected else "no",
            )
        )
        if metrics.solution_count != 1 or not metrics.connected or metrics.min_region_size < 2:
            has_errors = True

    headers = (
        "id",
        "name",
        "size",
        "diff",
        "sol",
        "score",
        "nodes",
        "branch",
        "dead",
        "edge",
        "minR",
        "two",
        "line",
        "nEnt",
        "dEnt",
        "conn",
    )
    print_table(headers, rows)
    return 1 if has_errors and args.fail_on_invalid else 0


def command_validate(args: argparse.Namespace) -> int:
    data = load_level_file(Path(args.input))
    has_errors = False
    for level in data["levels"]:
        errors = validate_level(level)
        level_id = int(level.get("levelId", 0))
        if errors:
            has_errors = True
            for error in errors:
                print(f"level {level_id}: {error}", file=sys.stderr)
    if not has_errors:
        print(f"VALID: {len(data['levels'])} levels")
        return 0
    return 1


def command_self_test(_: argparse.Namespace) -> int:
    specs = [
        ("simple", 5, 1),
        ("medium", 6, 1),
        ("hard", 7, 1),
        ("challenge", 8, 1),
    ]
    levels = generate_batch(101, specs, seed=4242, solution_pool_size=384)
    for level in levels:
        errors = validate_level(level)
        if errors:
            for error in errors:
                print(f"self-test level {level['levelId']}: {error}", file=sys.stderr)
            return 1

    simple_metrics = analyze_level(levels[0])
    if simple_metrics.two_cell_regions < 1:
        print("self-test simple level should include at least one fixed 2-cell region", file=sys.stderr)
        return 1

    print("PYTHON GENERATOR SELF-TEST PASSED")
    print_generation_summary(levels)
    return 0


def print_generation_summary(levels: list[dict[str, Any]], file: Any = sys.stdout) -> None:
    for level in levels:
        meta = level.get("generator", {})
        print(
            "generated level={level_id} difficulty={difficulty} size={size} score={score} "
            "attempt={attempt} pool={pool} matched={matched} two={two} canonical={canonical}".format(
                level_id=int(level["levelId"]),
                difficulty=str(level.get("difficulty", "-")),
                size=f"{int(level['rows'])}x{int(level['cols'])}",
                score=int(meta.get("score", 0)),
                attempt=int(meta.get("attempt", 0)),
                pool=int(meta.get("solutionPoolSize", 0)),
                matched=str(meta.get("matchedPreset", False)).lower(),
                two=int(meta.get("twoCellRegions", 0)),
                canonical=str(meta.get("canonicalColoring", ""))[:24],
            ),
            file=file,
        )


def print_table(headers: tuple[str, ...], rows: list[tuple[Any, ...]]) -> None:
    widths = [len(header) for header in headers]
    for row in rows:
        for index, value in enumerate(row):
            widths[index] = max(widths[index], len(str(value)))

    def format_row(row_values: Iterable[Any]) -> str:
        return "  ".join(str(value).ljust(widths[index]) for index, value in enumerate(row_values))

    print(format_row(headers))
    print(format_row("-" * width for width in widths))
    for row in rows:
        print(format_row(row))


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Offline Color Queens level generator")
    subparsers = parser.add_subparsers(dest="command", required=True)

    generate = subparsers.add_parser("generate", help="generate levels and output JSON")
    generate.add_argument("--difficulty", choices=sorted(DIFFICULTY_ALIASES), default="simple")
    generate.add_argument("--size", type=int, default=6)
    generate.add_argument("--count", type=int, default=1)
    generate.add_argument(
        "--plan",
        help="comma-separated plan, e.g. simple@5:10,medium@6:10,hard@8:5,challenge@9:3",
    )
    generate.add_argument("--start-id", type=int, default=None)
    generate.add_argument("--seed", type=int, default=None)
    generate.add_argument("--solution-pool", type=int, default=512)
    generate.add_argument("--append-from", help="existing JSON file to keep before generated levels")
    generate.add_argument("--output", default="-", help="output path, or '-' for stdout")
    generate.add_argument("--indent", type=int, default=2)
    generate.set_defaults(func=command_generate)

    analyze = subparsers.add_parser("analyze", help="print difficulty metrics for an existing JSON file")
    analyze.add_argument("input")
    analyze.add_argument("--fail-on-invalid", action="store_true")
    analyze.set_defaults(func=command_analyze)

    validate = subparsers.add_parser("validate", help="validate uniqueness and region connectivity")
    validate.add_argument("input")
    validate.set_defaults(func=command_validate)

    self_test = subparsers.add_parser("self-test", help="run a deterministic smoke test")
    self_test.set_defaults(func=command_self_test)
    return parser


def main(argv: list[str] | None = None) -> int:
    parser = build_parser()
    args = parser.parse_args(argv)
    try:
        return int(args.func(args))
    except Exception as exc:  # noqa: BLE001 - CLI should print a concise failure.
        print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
