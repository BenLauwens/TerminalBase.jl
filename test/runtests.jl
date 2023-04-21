using TerminalBase

let
    screen_init()
    screen_char('a', 1, 1; style=Style(;bold=true, background=RED, foreground=WHITE))
    screen_char('b', 1, 2; style=Style(;italic=true, background=WHITE, foreground=RED))
    screen_box(3, 10, 5, 30; style=Style(;background=BLUE, foreground=WHITE), type=DOUBLE)
    screen_box(5, 50, 4, 50; type=HEAVY)
    screen_update()
    sleep(2)
    y = 1
    x = 1
    n = 2
    m = 110
    screen_box(n, m, 7, 60; style=Style(;background=WHITE, foreground=RED), type=ROUNDED)
    screen_update()
    while true
        c = screen_input()
        screen_box_clear(n, m, 7, 60)
        if c === "q"
            break
        elseif c === UP
            n -= 1
        elseif c === DOWN
            n += 1
        elseif c === RIGHT
            m += 1
        elseif c === LEFT
            m -= 1
        elseif c === PGUP
            n = 1
        elseif startswith(c, "\e[M ")
            mouse = transcode(UInt8, c[5:6])
            y = Int(mouse[2]) - 32
            x = Int(mouse[1]) - 32
            screen_string("x = " * string(x) * "; y = " * string(y), screen_size(1), 5; width=15)
        end
        screen_box(n, m, 7, 60; style=Style(;background=WHITE, foreground=RED), type=ROUNDED)
        screen_string(repr(c), 10, 10; width=10)
        screen_update(y, x)
    end
end
