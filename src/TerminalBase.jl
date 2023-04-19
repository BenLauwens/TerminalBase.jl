module TerminalBase

import REPL

export BLACK, RED, GREEN, YELLOW, BLUE, MAGENTA, CYAN, WHITE
export BRIGHTBLACK, BRIGHTRED, BRIGHTGREEN, BRIGHTYELLOW, BRIGHTBLUE, BRIGHTMAGENTA, BRIGHTCYAN, BRIGHTWHITE
export BOX_LIGHT, BOX_ROUNDED, BOX_HEAVY, BOX_DOUBLE
export Style, Color256, ColorRGB
export screen_init, screen_update, screen_box, screen_string, screen_char, screen_input
export screen_foreground, screen_background, screen_width, screen_height

struct TerminalCommand
    v::Union{Char, String}
end

function Base.show(io::IO, cmd::TerminalCommand)
    print(io, REPL.Terminals.CSI, cmd.v)
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
const BRIGHTBLACK = Color256(8)
const BRIGHTRED = Color256(9)
const BRIGHTGREEN = Color256(10)
const BRIGHTYELLOW = Color256(11)
const BRIGHTBLUE = Color256(12)
const BRIGHTMAGENTA = Color256(13)
const BRIGHTCYAN = Color256(14)
const BRIGHTWHITE = Color256(15)

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
    terminal::REPL.Terminals.TTYTerminal
    width::Int
    height::Int
    background::Color
    foreground::Color
    buffers::NTuple{3,Matrix{Cell}}
    current::Ref{Int}
    inputs::Channel{Union{Char,String}}
end

function __init__()
    screen_init()
    nothing
end

function screen_init(; char::Char=' ', background::Color=BLACK, foreground::Color=GREEN)
    terminal = REPL.Terminals.TTYTerminal(get(ENV, "TERM", Sys.iswindows() ? "" : "dumb"), stdin, stdout, stderr)
    height, width = displaysize(terminal)
    buffers = (fill(Cell(char, Style(; background, foreground)), width, height),
        fill(Cell(char, Style(; background, foreground)), width, height),
        fill(Cell(char, Style(; background, foreground)), width, height)
    )
    inputs = Channel{Union{Char,String}}()
    SCREEN[] = Screen(terminal, width, height, background, foreground, buffers, Ref(1), inputs)
    REPL.Terminals.raw!(terminal, true)
    print(terminal, TerminalCommand("?1049h"))
    print(terminal, TerminalCommand("?25l"))
    print(terminal, TerminalCommand("?1000h"))
    print(terminal, TerminalCommand("2J"))
    print(terminal, TerminalCommand('H'))
    print(terminal, TerminalCommand("38;"), foreground, 'm')
    print(terminal, TerminalCommand("48;"), background, 'm')
    print(terminal, char^(height * width))
    print(terminal, TerminalCommand('H'))
    @async let
        io = IOBuffer()
        screen = SCREEN[]
        terminal = screen.terminal
        inputs = screen.inputs
        while true
            c = read(terminal, Char)
            if c === '\e'
                print(io, c)
                while bytesavailable(terminal) > 0
                    c = read(terminal, Char)
                    print(io, c)
                end
                put!(inputs, String(take!(io)))
            else
                put!(inputs, c)
            end
        end
    end
    atexit() do
        screen = SCREEN[]
        print(screen.terminal, TerminalCommand("?1000l"))
        print(screen.terminal, TerminalCommand("?25h"))
        print(screen.terminal, TerminalCommand("?1049l"))
        REPL.Terminals.raw!(screen.terminal, false)
    end
    nothing
end

const SCREEN = Ref{Screen}()

function screen_update()
    screen = SCREEN[]
    current = screen.buffers[screen.current[]]
    previous = screen.buffers[mod(screen.current[] - 2, 3)+1]
    screen.current[] = mod(screen.current[], 3) + 1
    copy!(current, screen.buffers[screen.current[]])
    style = nothing
    oldindex = 0
    io = IOBuffer()
    print(io, TerminalCommand('H'))
    for (index, cell) in enumerate(current)
        n, m = divrem(index - 1, screen.width)
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
    print(io, TerminalCommand('H'))
    print(screen.terminal, String(take!(io)))
    nothing
end

const BOX_LIGHT = ('┌', '─', '┐', '│', '└', '┘')
const BOX_ROUNDED = ('╭', '─', '╮', '│', '╰', '╯')
const BOX_HEAVY = ('┏', '━', '┓', '┃', '┗', '┛')
const BOX_DOUBLE = ('╔', '═', '╗', '║', '╚', '╝')

function screen_char(char::Char, row::Integer, col::Integer;
    style::Style=Style(; background=screen_background(), foreground=screen_foreground())
)
    screen = SCREEN[]
    if row <= screen.height && col <= screen.width
        screen.buffers[screen.current[]][col, row] = Cell(char, style)
    end
    nothing
end

function screen_string(str::String, row::Integer, col::Integer;
    style::Style=Style(; background=screen_background(), foreground=screen_foreground())
)
    for (index, char) in enumerate(str)
        screen_char(char, row, col + index - 1; style)
    end
    nothing
end

function screen_box(startrow::Integer, startcol::Integer, height::Integer, width::Integer;
    type::NTuple{6,Char}=BOX_LIGHT, style::Style=Style(; background=screen_background(), foreground=screen_foreground())
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

function screen_width()
    SCREEN[].width
end

function screen_height()
    SCREEN[].height
end

function screen_foreground()
    SCREEN[].foreground
end

function screen_background()
    SCREEN[].background
end

end
