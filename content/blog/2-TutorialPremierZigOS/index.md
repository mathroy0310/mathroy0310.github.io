---
.title = "Tutoriel : Créer votre premier Kernel Zig",
.description = "",
.author = "Mathieu Roy",
.layout = "post.shtml",
.date = @date("2024-09-03T10:50:00"),
.draft = false,
---

Salut à tous ! Aujourd'hui, nous allons plonger dans le monde fascinant du développement de systèmes d'exploitation en utilisant le langage de programmation Zig. Ce tutoriel est conçu pour les débutants en Zig et en développement de kernel. Nous allons créer un Kernel minimaliste pour l'architecture x86, en démarrant à partir du ROM BIOS.

## Prérequis

- [Zig 0.13 installé sur votre système](https://ziglang.org/download/)
- [QEMU pour l'émulation](https://www.qemu.org/download/)
- Des connaissances de base en programmation

## Structure du projet

Voici comment nous allons organiser notre projet :

```
MyFirstZigOS/
├── kernel/
│   ├── boot.zig
│   ├── kernel.zig
│   └── linker.ld
└── build.zig
```

## Étape 1 : Le bootloader (boot.zig)

Commençons par le bootloader. C'est la première partie de notre Kernel qui sera exécutée au démarrage.

```zig
// kernel/boot.zig
const std = @import("std");

// Constants pour l'en-tête multiboot
pub const ALIGN = 1 << 0;
pub const MEMINFO = 1 << 1;
pub const FLAGS = ALIGN | MEMINFO;
pub const MAGIC = 0x1BADB002;
pub const CHECKSUM = -(MAGIC + FLAGS);

// En-tête multiboot
export var multiboot_header align(4) linksection(".multiboot") = [_]i32{ MAGIC, FLAGS, CHECKSUM };

// Point d'entrée
export fn _start() callconv(.Naked) noreturn {
    @setRuntimeSafety(false);
    asm volatile (
        \\call kernel_main
        \\hlt
    );
    unreachable;
}
```

Explications :
- Nous définissons l'en-tête multiboot, qui permet au bootloader de reconnaître notre kernel.
- La fonction `_start` est le point d'entrée de notre Kernel. Elle appelle `kernel_main` et entre ensuite dans une boucle infinie (`hlt`).
- `@setRuntimeSafety(false)` désactive les vérifications de sécurité à l'exécution, car nous travaillons à un niveau très bas.

## Étape 2 : Le kernel (kernel.zig)

Maintenant, écrivons notre kernel minimaliste :

```zig
// kernel/kernel.zig
const std = @import("std");

// Pointeur vers le buffer de la mémoire vidéo
var terminal_buffer: [*]volatile u16 = @ptrFromInt(0xB8000);

// Fonction principale du kernel
export fn kernel_main() void {
    // Effacer l'écran
    for (0..25) |y| {
        for (0..80) |x| {
            const index = y * 80 + x;
            terminal_buffer[index] = @as(u16, ' ') | (@as(u16, 0x00) << 8);
        }
    }

    // Afficher un message
    const msg = "Hello, World from Zig Kernel!";
    var index: usize = 0;

    for (msg) |c| {
        terminal_buffer[index] = @as(u16, c) | (@as(u16, 0x0F) << 8);
        index += 1;
    }
}
```

Explications :
- Nous définissons un pointeur vers la mémoire vidéo (0xB8000 est l'adresse standard pour [le mode texte VGA](https://en.wikipedia.org/wiki/VGA_text_mode)).
- `kernel_main` efface d'abord l'écran en remplissant le buffer avec des espaces.
- Ensuite, nous affichons un message en écrivant directement dans le buffer vidéo.

## Étape 3 : Le script de liaison (linker.ld)

Le script de liaison est crucial pour placer correctement notre code en mémoire :

```
/* kernel/linker.ld */
ENTRY(_start)

SECTIONS {
    . = 1M;

    .text BLOCK(4K) : ALIGN(4K) {
        *(.multiboot)
        *(.text)
    }

    .rodata BLOCK(4K) : ALIGN(4K) {
        *(.rodata)
    }

    .data BLOCK(4K) : ALIGN(4K) {
        *(.data)
    }

    .bss BLOCK(4K) : ALIGN(4K) {
        *(COMMON)
        *(.bss)
    }
}
```

Ce script place notre code à partir de l'adresse 1 Mo et aligne les sections sur des frontières de 4 Ko.

## Étape 4 : Configuration de la compilation (build.zig)

Enfin, configurons notre build system avec Zig :

```zig
// build.zig
const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{ .default_target = .{
        .cpu_arch = .x86,
        .os_tag = .freestanding,
    } });
    const optimize = b.standardOptimizeOption(.{});

    const boot = b.addExecutable(.{
        .name = "MyFirstZigOS",
        .root_source_file = b.path("kernel/boot.zig"),
        .target = target,
        .optimize = optimize,
    });

    const kernel = b.addObject(.{
        .name = "MyFirstZigKernel",
        .root_source_file = b.path("kernel/kernel.zig"),
        .target = target,
        .optimize = optimize,
        .code_model = .kernel,
    });

    boot.setLinkerScriptPath(b.path("kernel/linker.ld"));
    boot.addObject(kernel);
    b.installArtifact(boot);

    const run_cmd = b.addSystemCommand(&[_][]const u8{
        "qemu-system-i386",
        "-kernel",
        "./zig-out/bin/MyFirstZigOS",
    });
    run_cmd.step.dependOn(b.getInstallStep());

    const run_step = b.step("run", "Run the kernel in QEMU");
    run_step.dependOn(&run_cmd.step);
}
```

Explications :
- Nous définissons une cible x86 freestanding (sans OS).
- Nous créons deux artefacts : `boot` (l'exécutable final) et `kernel` (un objet).
- Nous lions le tout avec notre script de liaison personnalisé.
- Nous ajoutons une commande pour exécuter notre kernel dans QEMU.

## Compilation et exécution

Pour compiler et exécuter votre kernel :

1. Placez-vous dans le répertoire du projet.
2. Exécutez `zig build` pour compiler.
3. Exécutez `zig build run` pour lancer le kernel dans QEMU.

Vous devriez voir **"Hello, World from Zig Kernel!"** s'afficher à l'écran !

## Conclusion

Félicitations ! Vous venez de créer votre premier kernel en Zig. C'est un début modeste, mais c'est la base sur laquelle vous pouvez construire. 

Le développement de kernel/d'OS est un domaine fascinant qui vous permettra d'approfondir votre compréhension des systèmes informatiques. N'hésitez pas à expérimenter et à poser des questions !

Bon codage, et à bientôt pour plus d'aventures en développement système !

Voici le code source [MyFirstZigOS](https://github.com/mathroy0310/MyFirstZigOS/tree/master)