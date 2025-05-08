# Q Git Commit Plugin

Un plugin para Oh My Zsh que utiliza Amazon Q para analizar cambios en Git y generar mensajes de commit siguiendo el formato de Conventional Commits.

## Características

- Analiza automáticamente los cambios en tu repositorio Git
- Genera mensajes de commit descriptivos y concisos siguiendo el formato de Conventional Commits
- Permite editar el mensaje generado antes de confirmar
- Opcionalmente confirma con el usuario antes de hacer push (según configuración)
- Permite usar o desactivar el uso de códigos de ticket en los commits
- Incluye alias `qc` para facilitar su uso

## Requisitos

- [Oh My Zsh](https://ohmyz.sh/)
- [Amazon Q CLI](https://aws.amazon.com/q/) instalado y configurado
- Git

## Instalación

### Instalación manual

1. Clona este repositorio en la carpeta de plugins personalizados de Oh My Zsh:

```bash
git clone https://github.com/eliecer2000/q-git-commit.git ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/q-git-commit
```

2. Agrega el plugin a la lista de plugins en tu archivo `.zshrc`:

```bash
plugins=(... q-git-commit)
```

3. Reinicia tu terminal o ejecuta `source ~/.zshrc`

## Configuración

Al ejecutar el plugin por primera vez, se creará un archivo de configuración llamado `.qcommitrc.yml` en la raíz del repositorio. Este archivo se utiliza para personalizar el comportamiento del plugin.

Las variables disponibles son:

- `ticket_code`: Código de ticket a incluir en el mensaje de commit (por ejemplo, `ABC-123`). Puede estar vacío.
- `confirm_commit`: (`true` o `false`) Si es `true`, el usuario podrá revisar y aprobar o editar el mensaje generado antes de confirmar el commit.
- `confirm_push`: (`true` o `false`) Si es `true`, el plugin pedirá confirmación antes de hacer `git push`.
- `unverified_commit`: (`true` o `false`) Si es `false`, no se permiten commits sin código de ticket.
- `language`: Idioma para las instrucciones que se envían a Amazon Q (por ejemplo, `"en"` o `"es"`).
- `use_ticket`: (`true` o `false`) Si es `true`, el plugin incluirá el código de ticket y preguntará si deseas actualizarlo en cada ejecución. Si es `false`, todo el flujo relacionado con ticket se omite.

Puedes editar este archivo directamente o volver a configurarlo borrando el archivo y ejecutando `qc` nuevamente.

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
3. Si está activado `confirm_commit`, te mostrará el mensaje y te dará opciones para:
   - Aceptar el mensaje (s)
   - Rechazar el mensaje (n)
   - Editar el mensaje antes de confirmar (e)
4. Si está activado `confirm_push`, te preguntará si deseas hacer push de los cambios

## Licencia

MIT ==
