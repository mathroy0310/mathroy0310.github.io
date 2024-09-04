---
.title = "Tutoriel : Créer votre premier Kernel Zig",
.description = "",
.author = "Mathieu Roy",
.layout = "post.shtml",
.date = @date("2024-09-03T10:50:00"),
.draft = false,
---

## Introduction

Bienvenue dans ce tutoriel approfondi sur la création d'un kernel minimaliste en utilisant le langage de programmation Zig. Ce guide est conçu pour les développeurs qui souhaitent plonger dans les profondeurs du développement système et comprendre les mécanismes fondamentaux qui sous-tendent les systèmes d'exploitation modernes.
Zig, un langage relativement nouveau dans l'écosystème des langages de programmation système, offre une approche rafraîchissante du développement bas niveau. Avec sa syntaxe claire, ses garanties de sécurité et sa capacité à interagir directement avec le matériel, Zig est un excellent choix pour l'écriture de kernels et de systèmes d'exploitation.

### Pourquoi créer un kernel en Zig ?

1. **Apprentissage approfondi** : La création d'un kernel vous permet de comprendre intimement le fonctionnement d'un ordinateur au niveau le plus bas.
2. **Maîtrise de Zig** : Ce projet vous fera explorer des aspects avancés de Zig, comme la programmation sans allocation dynamique et l'interaction directe avec le matériel.
3. **Exploration du développement système** : Vous découvrirez les défis uniques liés au développement de logiciels sans le support d'un système d'exploitation sous-jacent.


## Prérequis

Avant de commencer, assurez-vous d'avoir :

1. **Zig 0.13 ou supérieur** : 
   - Téléchargeable sur [https://ziglang.org/download/](https://ziglang.org/download/)
   - Vérifiez l'installation avec `zig version` dans votre terminal

2. **QEMU** :
   - Un émulateur puissant qui nous permettra de tester notre kernel sans matériel dédié
   - Téléchargeable sur [https://www.qemu.org/download/](https://www.qemu.org/download/)
   - Assurez-vous que `qemu-system-i386` est dans votre PATH

3. **Connaissances de base** :
   - Familiarité avec la programmation en général
   - Compréhension basique de l'architecture x86
   - Notions de base sur les systèmes d'exploitation

## Structure du projet

Voici comment nous allons organiser notre projet :

```
MyFirstZigOS/
├── kernel/
│   ├── boot.zig       # Code de démarrage et en-tête multiboot
│   ├── kernel.zig     # Fonctions principales du kernel
│   └── linker.ld      # Script de liaison pour organiser la mémoire
└── build.zig          # Script de construction Zig
```

Cette structure sépare clairement les différentes composantes de notre kernel :

- `boot.zig` contient le code exécuté au tout début du démarrage.
- `kernel.zig` contient la logique principale de notre kernel.
- `linker.ld` définit comment notre kernel sera organisé en mémoire.
- `build.zig` configure le processus de compilation.

## Étape 1 : Le bootloader (boot.zig)

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

#### Explications :
1. **En-tête Multiboot** :
   - Multiboot est un standard pour les bootloaders, permettant une interface commune entre le bootloader et le kernel.
   - `ALIGN` et `MEMINFO` sont des drapeaux indiquant nos besoins au bootloader.
   - `MAGIC` est une valeur spécifique que le bootloader recherche pour identifier un kernel compatible.
   - `CHECKSUM` est calculé pour vérifier l'intégrité de l'en-tête.

2. **Exportation de l'en-tête** :
   - `export var multiboot_header` rend l'en-tête visible pour le linker.
   - `align(4)` assure que l'en-tête est aligné sur une adresse divisible par 4, une exigence de nombreux processeurs x86.
   - `linksection(".multiboot")` place cet en-tête dans une section spécifique de notre binaire final.

3. **Fonction `_start`** :
   - C'est le véritable point d'entrée de notre kernel.
   - `callconv(.Naked)` indique qu'aucun prologue ou épilogue de fonction ne doit être généré.
   - `noreturn` signifie que cette fonction ne retournera jamais.
   - `@setRuntimeSafety(false)` désactive les vérifications de sécurité à l'exécution, nécessaire car nous opérons dans un environnement sans support runtime.
   - L'assembleur inline appelle `kernel_main` puis entre dans une boucle d'arrêt (`hlt`).


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

#### Explications :
1. **Mémoire vidéo** :
   - `0xB8000` est l'adresse standard du buffer vidéo en mode texte VGA.
   - Chaque caractère occupe 2 octets : un pour le caractère ASCII, un pour les attributs (couleur, etc.).
   - `volatile` indique au compilateur que cette mémoire peut changer indépendamment du flux du programme.

2. **Effacement de l'écran** :
   - Nous parcourons les 25 lignes et 80 colonnes standard du mode texte VGA.
   - Chaque cellule est remplie avec un espace (` `) et des attributs nuls (noir sur noir).

3. **Affichage du message** :
   - Chaque caractère est combiné avec l'attribut `0x0F` (blanc brillant sur noir) via un OU bitwise.
   - Le résultat est écrit directement dans le buffer vidéo, ce qui l'affiche instantanément à l'écran.

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
#### Explications :
1. **Point d'entrée** :
   - `ENTRY(_start)` définit `_start` comme le point d'entrée du programme.

2. **Adresse de chargement** :
   - `. = 1M` place le début de notre kernel à l'adresse 1 Mo, une convention courante pour les kernels x86.

3. **Sections** :
   - `.text` : contient le code exécutable, y compris notre en-tête multiboot.
   - `.rodata` : données en lecture seule (constantes, chaînes statiques).
   - `.data` : variables globales initialisées.
   - `.bss` : variables globales non initialisées.

4. **Alignement** :
   - `BLOCK(4K)` et `ALIGN(4K)` assurent que chaque section commence sur une frontière de page (4 Ko), important pour la gestion de la mémoire du kernel.

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

#### Explications :
1. **Configuration de la cible** :
   - `.cpu_arch = .x86` : nous ciblons l'architecture x86.
   - `.os_tag = .freestanding` : indique que nous compilons sans OS sous-jacent.

2. **Création des artefacts** :
   - `boot` est l'exécutable final, basé sur `boot.zig`.
   - `kernel` est un objet séparé, basé sur `kernel.zig`.
   - L'utilisation de `.code_model = .kernel` pour `kernel` optimise le code pour un environnement kernel.

3. **Liaison** :
   - `boot.setLinkerScriptPath(...)` utilise notre script de liaison personnalisé.
   - `boot.addObject(kernel)` inclut l'objet `kernel` dans l'exécutable final.

4. **Commande d'exécution** :
   - Configure QEMU pour exécuter notre kernel nouvellement compilé.


## Compilation et exécution

Pour compiler et exécuter votre kernel :

1. Ouvrez un terminal dans le répertoire du projet.
2. Exécutez `zig build` pour compiler le kernel.
   - Cette commande compile le code source et lie les objets selon les spécifications de `build.zig`.
3. Exécutez `zig build run` pour lancer le kernel dans QEMU.
   - Cette commande lance QEMU avec les paramètres appropriés pour charger et exécuter votre kernel.

Si tout se passe bien, vous devriez voir une fenêtre QEMU s'ouvrir avec le message **"Hello, World from Zig Kernel!"** affiché en haut à gauche de l'écran.

## Conclusion et perspectives

Félicitations ! Vous venez de créer et d'exécuter votre premier kernel en Zig. Bien que simple, ce kernel démontre plusieurs concepts fondamentaux :

1. **Démarrage bas niveau** : L'utilisation de l'en-tête Multiboot et la fonction `_start`.
2. **Interaction directe avec le matériel** : L'écriture dans le buffer vidéo.
3. **Compilation et liaison personnalisées** : L'utilisation d'un script de liaison et d'un build system Zig.

Ce n'est que le début de ce que vous pouvez accomplir. Voici quelques pistes pour approfondir vos connaissances :

- **kprint** : Implémentez un meilleur systeme pour ecrire dans le buffer video.
- **Interruptions** : Configurez la table d'interruption (IDT) pour gérer les interruptions matérielles et logicielles.
- **Global Descriptor Table** : Implémentez la structure de données (GDT) utilisée pour référencer les descripteurs de segment les plus utilisés par les processus.

Le développement de kernel est un domaine vaste et passionnant. Chaque nouvelle fonctionnalité que vous ajouterez vous fera plonger plus profondément dans les mécanismes internes des systèmes d'exploitation et de l'architecture des ordinateurs.

Bon codage, et que votre voyage dans le développement de kernel soit enrichissant et passionnant !

Voir le code source [MyFirstZigOS](https://github.com/mathroy0310/MyFirstZigOS/tree/master)