using TerminalBase
using Test

@testset "TerminalBase.jl" begin
    screen_char('a', 1, 1; style=Style(;bold=true, background=RED, foreground=WHITE))
    screen_char('b', 1, 2; style=Style(;italic=true, background=WHITE, foreground=RED))
    screen_box(3, 10, 5, 30; style=Style(;background=BLUE, foreground=WHITE), type = BOX_DOUBLE)
    screen_box(5, 50, 4, 50; type=BOX_HEAVY)
    screen_update()
    sleep(2)
    n = 2
    m = 110
    screen_box(n, m, 7, 60; style=Style(;background=WHITE, foreground=RED), type = BOX_ROUNDED)
    screen_update()
    while true
        c = screen_input()
        screen_cls(n, m, 7, 60)
        if c === "q"
            break
        elseif c === "\e[A"
            n -= 1
        elseif c === "\e[B"
            n += 1
        elseif c === "\e[C"
            m += 1
        elseif c === "\e[D"
            m -= 1
        elseif startswith(c, "\e[M ")
            mouse = transcode(UInt8, c[5:6])
            y = Int(mouse[2]) - 32
            x = Int(mouse[1]) - 32
            screen_cls(screen_height(), 5, 1, 20)
            screen_string("x = " * string(x) * "; y = " * string(y), screen_height(), 5)
        end
        screen_box(n, m, 7, 60; style=Style(;background=WHITE, foreground=RED), type = BOX_ROUNDED)
        screen_string(repr(c), 10, 10)
        screen_update()
    end
end
