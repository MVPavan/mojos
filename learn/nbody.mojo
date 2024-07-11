from math import sqrt
from collections import List

from benchmark import run, keep
from testing import assert_almost_equal

# alias compile time temporary value that cant change at runtime
alias PI = 3.141592653589793
alias SOLAR_MASS = 4 * PI * PI
alias DAYS_PER_YEAR = 365.24
alias Float64_4 = SIMD[DType.float64, 4]

@value
struct Planet:
    var pos: Float64_4
    var velocity: Float64_4
    var mass: Float64

alias Sun = Planet(0,0,SOLAR_MASS) 
# Equivalent to
# alias Sun = Planet(Float64_4(0,0,0,0),Float64_4(0,0,0,0),SOLAR_MASS) 

alias Jupiter = Planet(
    pos = Float64_4(
        4.84143144246472090e00,
        -1.16032004402742839e00,
        -1.03622044471123109e-01,
        0,
    ),
    velocity = Float64_4(
        1.66007664274403694e-03 * DAYS_PER_YEAR,
        7.69901118419740425e-03 * DAYS_PER_YEAR,
        -6.90460016972063023e-05 * DAYS_PER_YEAR,
        0,
    ),
    mass = 9.54791938424326609e-04 * SOLAR_MASS
)

alias Satrun = Planet(
    pos = Float64_4(
        8.34336671824457987e00,
        4.12479856412430479e00,
        -4.03523417114321381e-01,
        0,
    ),
    velocity = Float64_4(
        -2.76742510726862411e-03 * DAYS_PER_YEAR,
        4.99852801234917238e-03 * DAYS_PER_YEAR,
        2.30417297573763929e-05 * DAYS_PER_YEAR,
        0,
    ),
    mass = 2.85885980666130812e-04 * SOLAR_MASS
)

alias Uranus = Planet(
    pos = Float64_4(
        1.28943695621391310e01,
        -1.51111514016986312e01,
        -2.23307578892655734e-01,
        0,
    ),
    velocity = Float64_4(
        2.96460137564761618e-03 * DAYS_PER_YEAR,
        2.37847173959480950e-03 * DAYS_PER_YEAR,
        -2.96589568540237556e-05 * DAYS_PER_YEAR,
        0,
    ),
    mass = 4.36624404335156298e-05 * SOLAR_MASS
)

alias Neptune = Planet(
    pos = Float64_4(
        1.53796971148509165e01,
        -2.59193146099879641e01,
        1.79258772950371181e-01,
        0,
    ),
    velocity = Float64_4(
        2.68067772490389322e-03 * DAYS_PER_YEAR,
        1.62824170038242295e-03 * DAYS_PER_YEAR,
        -9.51592254519715870e-05 * DAYS_PER_YEAR,
        0,
    ),
    mass = 5.15138902046611451e-05 * SOLAR_MASS,
)

alias INITIAL_SYSTEM = List[Planet](Sun, Jupiter, Satrun, Uranus, Neptune)


fn offset_momentum(inout bodies: List[Planet]) -> NoneType:
    var p = Float64_4()

    for body in bodies:
        # body is declared with var and is not accessable ouside for
        # (variable) var body: Reference[Planet, 1, bodies, 0]
        p += body[].velocity * body[].mass
    
    # var body = bodies[0]
    # body.velocity = -p / SOLAR_MASS
    # bodies[0] = body

    bodies[0].velocity = -p / SOLAR_MASS


fn advance(inout bodies: List[Planet], dt: Float64):
    for i in range(len(INITIAL_SYSTEM)):
        for j in range(i+1, len(INITIAL_SYSTEM)):
            var body_i = bodies[i]
            var body_j = bodies[j]
            var diff = body_i.pos - body_j.pos
            var diff_sqr = (diff * diff).reduce_add()
            var mag = dt / (diff_sqr * sqrt(diff_sqr))

            body_i.velocity -= diff * body_j.mass * mag
            body_j.velocity += diff * body_i.mass * mag

            bodies[i] = body_i
            bodies[j] = body_j
    for body in bodies:
        body[].pos += dt * body[].velocity


fn energy(bodies: List[Planet]) -> Float64:
    var e: Float64 = 0
    for i in range(len(INITIAL_SYSTEM)):
        var body_i = bodies[i]
        e += (
            0.5
            * body_i.mass
            * (body_i.velocity * body_i.velocity).reduce_add()
        )
        for j in range(i+1, len(INITIAL_SYSTEM)):
            var body_j = bodies[j]
            var diff = body_i.pos - body_j.pos
            var distance = sqrt((diff * diff).reduce_add())
            # print(distance, e)
            e -= (body_i.mass * body_j.mass) / distance

    return e

def run_system():
    print("Starting nbody...")

    var system = INITIAL_SYSTEM
    offset_momentum(system)

    print("Energy of System:", energy(system))

    for i in range(50_000_000):
        advance(system, 0.01)

    var system_energy = energy(system)
    assert_almost_equal(system_energy, -0.1690599)
    print("Energy of System:", system_energy)


def benchmark():
    fn benchmark_fn():
        var system = INITIAL_SYSTEM
        offset_momentum(system)
        keep(energy(system))

        for i in range(50_000_000):
            advance(system, 0.01)

        keep(energy(system))

    run[benchmark_fn](max_runtime_secs=0.5).print()

def main():
    # run_system()
    benchmark()
