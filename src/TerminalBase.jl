module TerminalBase

import REPL.Terminals

export UP, DOWN, RIGHT, LEFT, PGUP, PGDN, ENTER, BACKSPACE, DELETE, INSERT
export ESCAPE, TAB, SHIFT_TAB, F1, F2, F3, F4, F5, F6, F7, F8, F9, F10
export BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE
export BRIGHT_BLACK, BRIGHT_RED, BRIGHT_GREEN, BRIGHT_YELLOW, BRIGHT_BLUE, BRIGHT_MAGENTA, BRIGHT_CYAN, BRIGHT_WHITE
export LIGHT, ROUNDED, HEAVY, DOUBLE
export Style, Color, Color256, ColorRGB
export screen_init, screen_update, screen_box, screen_string, screen_char, screen_input, screen_box_clear
export screen_color, screen_size

const UP = "\e[A"
const DOWN = "\e[B"
const RIGHT = "\e[C"
const LEFT = "\e[D"
const HOME = "\e[H"
const END = "\e[F"
const PGUP = "\e[5~"
const PGDN = "\e[6~"
const ENTER = "\r"
const BACKSPACE = "\x7f"
const DELETE = "\e[3~"
const INSERT = "\uf746"
const ESCAPE = "\e"
const TAB = "\t"
const SHIFT_TAB = "\e[Z"
const F1 = "\eOP"
const F2 = "\eOQ"
const F3 = "\eOR"
const F4 = "\eOS"
const F5 = "\e[15~"
const F6 = "\e[17~"
const F7 = "\e[18~"
const F8 = "\e[19~"
const F9 = "\e[20~"
const F10 = "\e[21~"

struct TerminalCommand
    v::String
end

function Base.show(io::IO, cmd::TerminalCommand)
    print(io, "\e[", cmd.v)
end

abstract type Color end

struct Color256 <: Color
    v::UInt8
end

function Base.show(io::IO, color::Color256)
    print(io, "5;", color.v)
end

struct ColorRGB <: Color
    r::UInt8
    g::UInt8
    b::UInt8
end

function Base.show(io::IO, color::ColorRGB)
    print(io, "2;", color.r, ';', color.g, ';', color.b)
end


const BLACK = Color256(0)
const RED = Color256(1)
const GREEN = Color256(2)
const YELLOW = Color256(3)
const BLUE = Color256(4)
const MAGENTA = Color256(5)
const CYAN = Color256(6)
const WHITE = Color256(7)
const BRIGHT_BLACK = Color256(8)
const BRIGHT_RED = Color256(9)
const BRIGHT_GREEN = Color256(10)
const BRIGHT_YELLOW = Color256(11)
const BRIGHT_BLUE = Color256(12)
const BRIGHT_MAGENTA = Color256(13)
const BRIGHT_CYAN = Color256(14)
const BRIGHT_WHITE = Color256(15)

struct Style
    bold::Bool
    italic::Bool
    underline::Bool
    strike::Bool
    background::Color
    foreground::Color
    function Style(; bold::Bool=false,
        italic::Bool=false,
        underline::Bool=false,
        strike::Bool=false,
        background::Color=BLACK,
        foreground::Color=GREEN
    )
        new(bold, italic, underline, strike, background, foreground)
    end
end

function Base.show(io::IO, style::Style)
    print(io, TerminalCommand("0m"))
    if style.bold
        print(io, TerminalCommand("1m"))
    end
    if style.italic
        print(io, TerminalCommand("3m"))
    end
    if style.underline
        print(io, TerminalCommand("4m"))
    end
    if style.strike
        print(io, TerminalCommand("9m"))
    end
    print(io, TerminalCommand("38;"), style.foreground, 'm')
    print(io, TerminalCommand("48;"), style.background, 'm')
end

struct Cell
    char::Char
    style::Style
end


function copy!(from::Matrix{Cell}, to::Matrix{Cell})
    for (index, cell) in enumerate(from)
        to[index] = cell
    end
    nothing
end

struct Screen
    terminal::Terminals.TTYTerminal
    background::Color
    foreground::Color
    buffers::NTuple{3,Matrix{Cell}}
    current::Ref{Int}
    inputs::Channel{String}
end

function screen_init(; char::Char=' ', background::Color=BLACK, foreground::Color=GREEN)
    terminal = Terminals.TTYTerminal(get(ENV, "TERM", Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)
    height, width = displaysize(terminal)
    buffers = (fill(Cell(char, Style(; background, foreground)), width, height),
        fill(Cell(char, Style(; background, foreground)), width, height),
        fill(Cell(char, Style(; background, foreground)), width, height)
    )
    inputs = Channel{String}()
    SCREEN[] = Screen(terminal, background, foreground, buffers, Ref(1), inputs)
    Terminals.raw!(terminal, true)
    #print(terminal, TerminalCommand("?1049h"))
    print(terminal, TerminalCommand("?25l"))
    print(terminal, TerminalCommand("?1000h"))
    print(terminal, TerminalCommand("2J"))
    print(terminal, TerminalCommand("H"))
    print(terminal, TerminalCommand("38;"), foreground, 'm')
    print(terminal, TerminalCommand("48;"), background, 'm')
    print(terminal, char^(height * width))
    print(terminal, TerminalCommand("H"))
    @async let
        io = IOBuffer()
        terminal = SCREEN[].terminal
        inputs = SCREEN[].inputs
        while true
            c = read(terminal, Char)
            print(io, c)
            if c === '\e'
                while bytesavailable(terminal) > 0
                    c = read(terminal, Char)
                    print(io, c)
                end
            end
            put!(inputs, String(take!(io)))
        end
    end
    atexit() do
        terminal = SCREEN[].terminal
        print(terminal, TerminalCommand("?1000l"))
        print(terminal, TerminalCommand("?25h"))
        print(terminal, TerminalCommand("?1049l"))
        Terminals.raw!(terminal, false)
    end
    nothing
end

const SCREEN = Ref{Screen}()

function screen_update(row::Integer=0, col::Integer=0)
    screen = SCREEN[]
    current = screen.buffers[screen.current[]]
    previous = screen.buffers[mod(screen.current[] - 2, 3)+1]
    screen.current[] = mod(screen.current[], 3) + 1
    copy!(current, screen.buffers[screen.current[]])
    style = nothing
    oldindex = 0
    io = IOBuffer()
    print(io, TerminalCommand("H"))
    for (index, cell) in enumerate(current)
        n, m = divrem(index - 1, screen_size(2))
        if cell !== previous[index]
            if oldindex !== index - 1
                print(io, TerminalCommand(string(n + 1) * ';' * string(m + 1) * 'H'))
            end
            if cell.style !== style
                print(io, cell.style)
                style = cell.style
            end
            print(io, cell.char)
            oldindex = index
        end
    end
    if row === 0 || col === 0
        print(io, TerminalCommand("H"))
        print(io, TerminalCommand("?25l"))
    else
        print(io, TerminalCommand(string(row) * ';' * string(col) * 'H'))
        print(io, TerminalCommand("?25h"))
    end
    print(screen.terminal, String(take!(io)))
    nothing
end

const LIGHT = ('┌', '─', '┐', '│', '└', '┘')
const ROUNDED = ('╭', '─', '╮', '│', '╰', '╯')
const HEAVY = ('┏', '━', '┓', '┃', '┗', '┛')
const DOUBLE = ('╔', '═', '╗', '║', '╚', '╝')

function screen_char(char::Char, row::Integer, col::Integer;
    style::Style=Style(; background=screen_color(2), foreground=screen_color(1))
)
    screen = SCREEN[]
    height, width = screen_size()
    if 0 < row <= height && 0 < col <= width
        screen.buffers[screen.current[]][col, row] = Cell(char, style)
    end
    nothing
end

function screen_string(str::String, row::Integer, col::Integer;
    style::Style=Style(; background=screen_color(2), foreground=screen_color(1)),
    width::Integer=length(str)
)
    for (index, char) in enumerate(rpad(str, width))
        screen_char(char, row, col + index - 1; style)
    end
    nothing
end

function screen_box_clear(startrow::Integer=1, startcol::Integer=1, height::Integer=screen_size(1), width::Integer=screen_size(2);
    style::Style=Style(; background=screen_color(2), foreground=screen_color(1))
)
    screen_box(startrow, startcol, height, width; type=(' ', ' ', ' ', ' ', ' ', ' '), style)
    nothing
end

function screen_box(startrow::Integer, startcol::Integer, height::Integer, width::Integer;
    type::NTuple{6,Char}=LIGHT, style::Style=Style(; background=screen_color(2), foreground=screen_color(1))
)
    screen_string(type[1] * type[2]^(width - 2) * type[3], startrow, startcol; style)
    for row in startrow+1:startrow+height-2
        screen_string(type[4] * ' '^(width - 2) * type[4], row, startcol; style)
    end
    screen_string(type[5] * type[2]^(width - 2) * type[6], startrow + height - 1, startcol; style)
    nothing
end

function screen_input()
    take!(SCREEN[].inputs)
end

function screen_size(dim::Integer=0)
    height, width = displaysize(SCREEN[].terminal)
    if dim === 1
        height
    elseif dim === 2
        width
    else
        height, width
    end
end

function screen_color(dim::Integer=0)
    screen = SCREEN[]
    if dim === 1
        screen.foreground
    elseif dim === 2
        screen.background
    else
        screen.foreground, screen.background
    end
end

end
