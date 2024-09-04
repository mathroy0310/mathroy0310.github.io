---
.title = "La gestion de la mémoire dans le développement de kernels",
.description = "",
.author = "Mathieu Roy",
.layout = "post.shtml",
.date = @date("2024-09-01T09:11:00"),
.draft = false,
---

Salut à tous ! le sujet d'aujourd'hui, un aspect crucial du développement de kernels de systèmes d'exploitation : la gestion de la mémoire. Attachez vos ceintures, on plonge dans le vif du sujet !

## Introduction

La gestion de la mémoire est l'une des responsabilités les plus critiques d'un kernel. Elle affecte directement les performances, la stabilité et la sécurité de votre système d'exploitation. Dans cet article, nous allons explorer les concepts clés et les techniques utilisées pour implémenter une gestion de mémoire efficace dans un kernel.

## Les bases de la gestion de la mémoire

### 1. Segmentation vs Pagination

Il existe deux approches principales pour la gestion de la mémoire :

### Segmentation

La segmentation divise la mémoire en segments de tailles variables. Chaque segment est défini par une base (adresse de début) et une limite (taille).

**Avantages :**
- Simplicité conceptuelle
- Bonne pour la protection de la mémoire

**Inconvénients :**
- Fragmentation externe
- Complexité de l'allocation de mémoire

### Pagination

La pagination divise la mémoire en pages de taille fixe (généralement 4 KB). L'espace d'adressage virtuel est également divisé en pages, mappées aux pages physiques via une table de pages.

**Avantages :**
- Pas de fragmentation externe
- Facilite la mémoire virtuelle

**Inconvénients :**
- Peut entraîner une fragmentation interne
- Nécessite plus de mémoire pour les structures de données de gestion

La plupart des systèmes modernes utilisent la pagination, parfois combinée avec la segmentation pour certains usages spécifiques.

### 2. Implémentation de la pagination

Voici un exemple simplifié de structure pour une entrée de table de pages en C :

```c
typedef struct {
    uint32_t present    : 1;   // Page présente en mémoire
    uint32_t rw         : 1;   // Permissions de lecture/écriture
    uint32_t user       : 1;   // Permissions utilisateur/superviseur
    uint32_t accessed   : 1;   // Page accédée
    uint32_t dirty      : 1;   // Page modifiée
    uint32_t unused     : 7;   // Bits non utilisés
    uint32_t frame      : 20;  // Adresse du frame (12 bits de poids faible supposés à 0)
} page_entry_t;
```

### 3. Allocation de mémoire physique

L'allocation de mémoire physique est une tâche cruciale du kernel. Voici un exemple simple d'allocateur de pages utilisant un bitmap :

```c
#define PAGES_PER_BYTE 8
#define PAGE_SIZE 4096

static uint8_t *frame_bitmap;
static uint32_t num_frames;

void init_frame_allocator(uint32_t mem_size) {
    num_frames = mem_size / PAGE_SIZE;
    frame_bitmap = (uint8_t*) kmalloc(num_frames / PAGES_PER_BYTE);
    memset(frame_bitmap, 0, num_frames / PAGES_PER_BYTE);
}

uint32_t allocate_frame() {
    for (uint32_t i = 0; i < num_frames / PAGES_PER_BYTE; i++) {
        if (frame_bitmap[i] != 0xFF) {  // Au moins un bit est libre
            for (int j = 0; j < PAGES_PER_BYTE; j++) {
                uint8_t test_bit = 1 << j;
                if (!(frame_bitmap[i] & test_bit)) {
                    frame_bitmap[i] |= test_bit;
                    return i * PAGES_PER_BYTE + j;
                }
            }
        }
    }
    return (uint32_t)-1;  // Pas de frame libre
}
```

## Techniques avancées de gestion de la mémoire

### 1. Mémoire virtuelle

La mémoire virtuelle permet à chaque processus d'avoir son propre espace d'adressage, isolé des autres processus. Elle permet également d'utiliser plus de mémoire que ce qui est physiquement disponible en utilisant le disque comme extension de la RAM.

### 2. Copy-on-Write (CoW)

Le CoW est une technique d'optimisation qui permet de partager des pages mémoire entre processus jusqu'à ce qu'une écriture soit nécessaire. C'est particulièrement utile pour l'implémentation efficace du `fork()` dans les systèmes UNIX-like.

### 3. Allocation de mémoire pour le kernel

L'allocation dynamique de mémoire dans le kernel est un défi en soi. Beaucoup de kernels implémentent leur propre version de `malloc()` et `free()`. Voici un exemple simplifié d'un allocateur de type "slab" :

```c
#define SLAB_SIZE 4096

typedef struct slab {
    size_t obj_size;
    void *free_list;
    struct slab *next;
} slab_t;

void* slab_alloc(slab_t *slab) {
    if (!slab->free_list) {
        // Allouer un nouveau slab si nécessaire
        size_t slab_mem_size = SLAB_SIZE - sizeof(slab_t);
        void *new_slab_mem = malloc(slab_mem_size);
        if (!new_slab_mem) {
            return NULL; // Échec de l'allocation
        }

        // Initialiser la liste libre avec les nouveaux objets
        slab->free_list = new_slab_mem;
        void *current_obj = new_slab_mem;
        for (size_t i = 0; i < slab_mem_size / slab->obj_size - 1; ++i) {
            void *next_obj = (char*)current_obj + slab->obj_size;
            *(void**)current_obj = next_obj;
            current_obj = next_obj;
        }
        *(void**)current_obj = NULL; // Dernier objet pointe vers NULL
    }
    void *obj = slab->free_list;
    slab->free_list = *(void**)obj;
    return obj;
}

void slab_free(slab_t *slab, void *obj) {
    *(void**)obj = slab->free_list;
    slab->free_list = obj;
}
```

## Défis et considérations

1. **Fragmentation** : La fragmentation peut réduire l'efficacité de l'utilisation de la mémoire. Les allocateurs doivent être conçus pour minimiser ce problème.

2. **Performances** : La gestion de la mémoire est sur le chemin critique de nombreuses opérations. L'efficacité est cruciale.

3. **Sécurité** : La protection de la mémoire est essentielle pour isoler les processus et prévenir les accès non autorisés.

4. **Gestion des erreurs** : Le kernel doit gérer gracieusement les situations de mémoire insuffisante.

## Conclusion

La gestion de la mémoire dans un kernel est un sujet vaste et complexe. Nous n'avons qu'effleuré la surface ici, mais j'espère que cela vous a donné un aperçu des défis et des techniques impliqués.

Dans les prochains articles, nous explorerons d'autres aspects du développement de kernel, comme l'ordonnancement des processus ou la gestion des systèmes de fichiers. A voir quel sera le prochain.

## Ressources pour aller plus loin

- [OSDev Wiki](https://osdev.wiki/wiki/Expanded_Main_Page) : Une mine d'or pour les développeurs de systèmes d'exploitation. (autrefois *wiki.osdev.org* maintenant *osdev.wiki* simplement )
- ["Operating Systems: Three Easy Pieces"](https://techiefood4u.wordpress.com/wp-content/uploads/2020/02/operating_systems_three_easy_pieces.pdf) : Un excellent livre gratuit sur les systèmes d'exploitation.
- [Linux Kernel Development](https://www.doc-developpement-durable.org/file/Projets-informatiques/cours-&-manuels-informatiques/Linux/Linux%20Kernel%20Development,%203rd%20Edition.pdf) de Robert Love : Pour ceux qui veulent plonger dans le code du kernel Linux.

Joyeux codage, et à la prochaine pour plus d'aventures au cœur des systèmes d'exploitation !