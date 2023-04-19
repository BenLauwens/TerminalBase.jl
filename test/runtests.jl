using TerminalBase
using Test

@testset "TerminalBase.jl" begin
    screen_char('a', 1, 1; style=Style(;bold=true, background=RED, foreground=WHITE))
    screen_char('b', 1, 2; style=Style(;italic=true, background=WHITE, foreground=RED))
    screen_box(3, 10, 5, 30; style=Style(;background=BLUE, foreground=WHITE), type = BOX_DOUBLE)
    screen_box(5, 50, 4, 50; type=BOX_HEAVY)
    screen_update()
    sleep(2)
    screen_box(2, 110, 7, 60; style=Style(;background=WHITE, foreground=RED), type = BOX_ROUNDED)
    screen_update()
    while true
        c = screen_input()
        if c == 'q'
            break
        end
        screen_string(repr(c), 10, 10)
        screen_update()
    end
end
