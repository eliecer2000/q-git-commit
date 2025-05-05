# Q Git Commit Plugin

Un plugin para Oh My Zsh que utiliza Amazon Q para analizar cambios en Git y generar mensajes de commit siguiendo el formato de Conventional Commits.

## Características

- Analiza automáticamente los cambios en tu repositorio Git
- Genera mensajes de commit descriptivos y concisos siguiendo el formato de Conventional Commits
- Permite editar el mensaje generado antes de confirmar
- Ofrece la opción de hacer push después del commit
- Incluye alias `qc` para facilitar su uso

## Requisitos

- [Oh My Zsh](https://ohmyz.sh/)
- [Amazon Q CLI](https://aws.amazon.com/q/) instalado y configurado
- Git

## Instalación

### Instalación manual

1. Clona este repositorio en la carpeta de plugins personalizados de Oh My Zsh:

```bash
git clone https://github.com/TU_USUARIO/q-git-commit-plugin.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/q-git-commit
```

2. Agrega el plugin a la lista de plugins en tu archivo `.zshrc`:

```bash
plugins=(... q-git-commit)
```

3. Reinicia tu terminal o ejecuta `source ~/.zshrc`

## Uso

Cuando estés en un repositorio Git con cambios, simplemente ejecuta:

```bash
qcommit
```

O usa el alias más corto:

```bash
qc
```

El plugin:
1. Analizará los cambios en tu repositorio
2. Utilizará Amazon Q para generar un mensaje de commit adecuado
3. Te mostrará el mensaje y te dará opciones para:
   - Aceptar el mensaje (s)
   - Rechazar el mensaje (n)
   - Editar el mensaje antes de confirmar (e)
4. Después del commit, te preguntará si deseas hacer push de los cambios

## Licencia

MIT
