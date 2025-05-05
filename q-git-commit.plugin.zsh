#!/bin/zsh

# q-git-commit.plugin.zsh
# Plugin para Oh My Zsh que utiliza Amazon Q para analizar cambios y generar mensajes de commit convencionales

qcommit() {
  # Verificar si estamos en un repositorio git
  if ! git rev-parse --is-inside-work-tree &>/dev/null; then
    echo "❌ No estás dentro de un repositorio Git."
    return 1
  fi

  # Verificar si hay cambios para hacer commit
  if git diff-index --quiet HEAD -- && [ -z "$(git ls-files --others --exclude-standard)" ]; then
    echo "❌ No hay cambios para hacer commit."
    return 1
  fi

  echo "🔍 Analizando cambios con Amazon Q..."
  
  # Obtener información detallada sobre los cambios
  GIT_STATUS=$(git status)
  
  # Obtener un resumen de los archivos modificados
  MODIFIED_FILES=$(git diff --name-status)
  STAGED_FILES=$(git diff --name-status --staged)
  
  # Obtener la lista de archivos no rastreados
  UNTRACKED=$(git ls-files --others --exclude-standard | xargs -I{} echo "Nuevo archivo: {}")
  
  # Obtener la rama actual
  CURRENT_BRANCH=$(git branch --show-current)
  
  # Crear un archivo temporal con la solicitud para evitar problemas de formato
  TEMP_REQUEST_FILE=$(mktemp)
  echo "Genera un mensaje de commit siguiendo el formato de Conventional Commits (tipo: descripción) basado en estos cambios de git. El mensaje debe ser descriptivo y conciso. Usa uno de estos tipos: feat, fix, docs, style, refactor, perf, test, build, ci, chore, revert.

Rama actual: $CURRENT_BRANCH

Estado del repositorio:
$GIT_STATUS

Archivos modificados (no preparados):
$MODIFIED_FILES

Archivos preparados para commit:
$STAGED_FILES

Archivos no rastreados:
$UNTRACKED

IMPORTANTE: Responde SOLO con el mensaje de commit, sin explicaciones adicionales ni texto introductorio." > "$TEMP_REQUEST_FILE"
  
  # Usar Amazon Q para generar el mensaje de commit
  COMMIT_MSG=$(q chat --no-interactive --trust-all-tools < "$TEMP_REQUEST_FILE")
  
  # Eliminar el archivo temporal
  rm "$TEMP_REQUEST_FILE"
  
  # Usar un enfoque más simple para extraer el mensaje de commit
  # Guardar la respuesta completa para depuración
  echo "$COMMIT_MSG" > /tmp/q_commit_full_response.txt
  
  # Eliminar códigos de color y formato ANSI
  CLEAN_MSG=$(echo "$COMMIT_MSG" | sed -r "s/\x1B\[([0-9]{1,3}(;[0-9]{1,3})*)?[mGK]//g")
  
  # Buscar el mensaje de commit en formato convencional (feat:, fix:, etc.)
  if echo "$CLEAN_MSG" | grep -q "^feat:\|^fix:\|^docs:\|^style:\|^refactor:\|^perf:\|^test:\|^build:\|^ci:\|^chore:\|^revert:"; then
    # Extraer desde la línea que comienza con el tipo hasta el final
    COMMIT_MSG=$(echo "$CLEAN_MSG" | grep -A 50 "^feat:\|^fix:\|^docs:\|^style:\|^refactor:\|^perf:\|^test:\|^build:\|^ci:\|^chore:\|^revert:")
  else
    # Si no encontramos el formato convencional, buscar después de frases comunes
    if echo "$CLEAN_MSG" | grep -q "El mensaje de commit adecuado sería:"; then
      COMMIT_MSG=$(echo "$CLEAN_MSG" | sed -n '/El mensaje de commit adecuado sería:/,/^$/p' | tail -n +2)
    elif echo "$CLEAN_MSG" | grep -q "El mensaje de commit sería:"; then
      COMMIT_MSG=$(echo "$CLEAN_MSG" | sed -n '/El mensaje de commit sería:/,/^$/p' | tail -n +2)
    else
      # Si todo lo demás falla, usar la respuesta completa limpia
      COMMIT_MSG="$CLEAN_MSG"
    fi
  fi
  
  # Verificar si el mensaje está vacío y usar un mensaje predeterminado si es necesario
  if [ -z "$COMMIT_MSG" ]; then
    echo "⚠️ No se pudo extraer un mensaje de commit. Usando la respuesta completa de Amazon Q."
    COMMIT_MSG="$CLEAN_MSG"
  fi
  
  # Mostrar el mensaje generado y pedir confirmación
  echo "\n📝 Mensaje de commit generado:"
  echo "----------------------------------------"
  echo "$COMMIT_MSG"
  echo "----------------------------------------"
  
  echo -n "¿Quieres usar este mensaje para el commit? (s/n/e para editar): "
  read CONFIRM
  
  if [[ "$CONFIRM" == "s" || "$CONFIRM" == "S" ]]; then
    # Agregar todos los cambios
    git add -A
    
    # Realizar el commit con el mensaje generado y sin verificación (-n)
    git commit -n -m "$COMMIT_MSG"
    
    echo "✅ Commit realizado con éxito."
    
    # Preguntar si quiere hacer push
    echo -n "¿Quieres hacer push de los cambios a la rama $CURRENT_BRANCH? (s/n): "
    read PUSH_CONFIRM
    
    if [[ "$PUSH_CONFIRM" == "s" || "$PUSH_CONFIRM" == "S" ]]; then
      git push origin $CURRENT_BRANCH
      echo "✅ Push realizado con éxito a $CURRENT_BRANCH."
    fi
    
  elif [[ "$CONFIRM" == "e" || "$CONFIRM" == "E" ]]; then
    # Abrir editor para modificar el mensaje
    echo "$COMMIT_MSG" > /tmp/commit_msg_temp
    ${EDITOR:-vim} /tmp/commit_msg_temp
    EDITED_MSG=$(cat /tmp/commit_msg_temp)
    
    # Agregar todos los cambios
    git add -A
    
    # Realizar el commit con el mensaje editado y sin verificación (-n)
    git commit -n -m "$EDITED_MSG"
    
    echo "✅ Commit realizado con éxito."
    rm /tmp/commit_msg_temp
    
    # Preguntar si quiere hacer push
    echo -n "¿Quieres hacer push de los cambios a la rama $CURRENT_BRANCH? (s/n): "
    read PUSH_CONFIRM
    
    if [[ "$PUSH_CONFIRM" == "s" || "$PUSH_CONFIRM" == "S" ]]; then
      git push origin $CURRENT_BRANCH
      echo "✅ Push realizado con éxito a $CURRENT_BRANCH."
    fi
  else
    echo "❌ Commit cancelado."
    return 1
  fi
}

# Alias para facilitar el uso
alias qc="qcommit"
