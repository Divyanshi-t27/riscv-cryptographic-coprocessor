<CodeBlock language="python" editable>
P = []
L = {}

def emit(x):
    P.append(x)

def label(n):
    L[n] = len(P)

def I(op, f3, rd, rs1, imm):
    emit(((imm & 0xFFF) << 20) |
         (rs1 << 15) | (f3 << 12) | (rd << 7) | op)

def addi(rd, rs, imm):
    I(0x13, 0, rd, rs, imm)

def andi(rd, rs, imm):
    I(0x13, 7, rd, rs, imm)

def lw(rd, off, rs1):
    I(0x03, 2, rd, rs1, off)

def sw(rs2, off, rs1):
    imm = off & 0xFFF
    emit(((imm >> 5) << 25) |
         (rs2 << 20) |
         (rs1 << 15) |
         (2 << 12) |
         ((imm & 31) << 7) |
         0x23)

def add(rd, a, b):
    emit((b << 20) | (a << 15) |
         (0 << 12) | (rd << 7) | 0x33)

def bne(a, b, lab):
    emit(('b', 1, a, b, lab))

def jal(rd, lab):
    emit(('j', rd, lab))

def li(rd, v):
    v &= 0xFFFFFFFF
    s = v - (1 << 32) if v >= 0x80000000 else v

if -2048 <= s < 2048:
        addi(rd, 0, s)
        return

hi = ((v + 0x800) >> 12) & 0xFFFFF
    lo = ((v & 0xFFF) ^ 0x800) - 0x800

    emit((hi << 12) | (rd << 7) | 0x37)

if lo:
        addi(rd, rd, lo)
Register offsets in the crypto MMIO interface
KEY, PT, CT = 4, 8, 12
Shared crypto base and simulation console base
li(10, 0x40000000 + 1 * 0x1000)
li(11, 0x50000000)
Test marker
li(12, 0xA0000001)
sw(12, 0, 11)
Read encryption mode and print it
lw(5, 0x100, 11)
sw(5, 0x14, 11)
Transfer four 32-bit key words
for i in range(4):
lw(12, 0x110 + 4 * i, 11)
sw(12, (KEY + i) * 4, 10)
sw(12, 0x08, 11)
Transfer four 32-bit plaintext words
for i in range(4):
lw(12, 0x120 + 4 * i, 11)
sw(12, (PT + i) * 4, 10)
sw(12, 0x0C, 11)
Write mode and start bit
add(12, 5, 5)
addi(12, 12, 1)
sw(12, 0, 10)
Poll for completion with timeout
li(15, 100000)
label('poll')

lw(13, 4, 10)
andi(13, 13, 2)
bne(13, 0, 'done')

addi(15, 15, -1)
bne(15, 0, 'poll')
Timeout path
li(12, 0xBAD0BAD0)
sw(12, 0, 11)
jal(0, 'fin')
Read and print ciphertext
label('done')

for i in range(4):
    lw(13, (CT + i) * 4, 10)
    sw(13, 0x10, 11)

li(12, 0xD0D0D0D0)
sw(12, 0, 11)

label('fin')
li(12, 1)
sw(12, 4, 11)

label('hang')
jal(0, 'hang')
Resolve branch and jump labels and encode instructions
out = []

for idx, x in enumerate(P):
    if isinstance(x, tuple):
        if x[0] == 'b':
            _, f3, rs1, rs2, lab = x
            o = (L[lab] - idx) * 4

imm12 = (o >> 12) & 0x1
            imm11 = (o >> 11) & 0x1
            imm10_5 = (o >> 5) & 0x3F
            imm4_1 = (o >> 1) & 0xF

x = ((imm12 << 31) |
                 (imm10_5 << 25) |
                 (rs2 << 20) |
                 (rs1 << 15) |
                 (f3 << 12) |
                 (imm4_1 << 8) |
                 (imm11 << 7) |
                 0x63)

else:
            _, rd, lab = x
            o = (L[lab] - idx) * 4

imm20 = (o >> 20) & 0x1
            imm19_12 = (o >> 12) & 0xFF
            imm11 = (o >> 11) & 0x1
            imm10_1 = (o >> 1) & 0x3FF

x = ((imm20 << 31) |
                 (imm10_1 << 21) |
                 (imm11 << 20) |
                 (imm19_12 << 12) |
                 (rd << 7) |
                 0x6F)

    out.append('%08x' % x)

with open('firmware.hex', 'w') as f:
    f.write('\n'.join(out) + '\n')

print('wrote firmware.hex with %d words' % len(out))
</CodeBlock>
