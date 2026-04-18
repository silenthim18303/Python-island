const contentEl = document.getElementById("content");
const toggleBtn = document.getElementById("toggle-btn");
const stateLabel = document.getElementById("state-label");
const capsuleEl = document.getElementById("capsule");
const input = document.getElementById("memo-input");
const addBtn = document.getElementById("add-btn");
const voiceBtn = document.getElementById("voice-btn");
const clearBtn = document.getElementById("clear-btn");
const listEl = document.getElementById("memo-list");

const memos = [];
let capsuleBridge = null;
const MAX_IMAGE_SIZE_BYTES = 50 * 1024 * 1024;
let voiceListening = false;

function setVoiceButtonState(listening, label) {
  voiceListening = listening;
  voiceBtn.classList.toggle("listening", listening);
  voiceBtn.textContent = label || (listening ? "停止语音" : "语音输入");
}

function render() {
  if (!memos.length) {
    listEl.innerHTML = '<div class="empty">还没有备忘录，先写下第一条吧</div>';
    return;
  }

  listEl.innerHTML = memos
    .map((memo, idx) => {
      if (memo.type === "image") {
        return `<li class="item"><div class="item-content"><img class="memo-image" src="${memo.src}" alt="粘贴图片备忘录" /></div><button data-idx="${idx}" type="button">删除</button></li>`;
      }
      if (memo.type === "file") {
        const safePath = escapeHtml(memo.path || "");
        return `<li class="item"><div class="item-content"><button class="file-link" data-path="${safePath}" type="button">${safePath}</button></div><button data-idx="${idx}" type="button">删除</button></li>`;
      }
      return `<li class="item"><div class="item-content"><span>${escapeHtml(memo.text)}</span></div><button data-idx="${idx}" type="button">删除</button></li>`;
    })
    .join("");
}

function toggleVoiceInput() {
  if (!capsuleBridge) return;

  if (voiceListening) {
    capsuleBridge.stopVoiceInput();
    setVoiceButtonState(false, "语音输入");
    return;
  }

  setVoiceButtonState(true, "正在启动...");
  capsuleBridge.startVoiceInput((status) => {
    if (status === "already_running") {
      setVoiceButtonState(true, "正在识别...");
      return;
    }
    if (status === "started") {
      setVoiceButtonState(true, "正在识别...");
      return;
    }
    setVoiceButtonState(false, "语音输入");
  });
}

window.onVoiceResult = (text) => {
  if (typeof text !== "string") return;
  const recognized = text.replace(/\s+/g, "").trim();
  if (!recognized) return;

  input.value = input.value.trim() ? `${input.value.trim()} ${recognized}` : recognized;
  input.focus();
};

window.onVoiceStatus = (status) => {
  if (status === "listening") {
    setVoiceButtonState(true, "正在识别...");
    return;
  }
  if (status === "stopped") {
    setVoiceButtonState(false, "语音输入");
  }
};

window.onVoiceError = (message) => {
  setVoiceButtonState(false, "语音输入");
  if (typeof message === "string" && message) {
    alert(message);
  }
};

window.cleanupCapsuleState = () => {
  if (voiceListening) {
    return;
  }
};

function persistTodos() {
  if (!capsuleBridge) return;
  capsuleBridge.saveTodos(JSON.stringify(memos));
}

function hydrateTodos(payload) {
  try {
    const parsed = JSON.parse(payload || "[]");
    if (!Array.isArray(parsed)) {
      render();
      return;
    }
    memos.splice(0, memos.length, ...parsed);
    render();
  } catch {
    render();
  }
}

function addFileMemo(filePath) {
  if (!filePath) return;
  memos.unshift({ type: "file", path: filePath });
  render();
  persistTodos();
}

function normalizeFileUrlToPath(fileUrl) {
  try {
    const url = new URL(fileUrl);
    if (url.protocol !== "file:") return "";
    let pathname = decodeURIComponent(url.pathname || "");
    if (/^\/[A-Za-z]:/.test(pathname)) {
      pathname = pathname.slice(1);
    }
    return pathname.replaceAll("/", "\\");
  } catch {
    return "";
  }
}

function extractDropFilePaths(event) {
  const paths = [];
  const uriListRaw = event.dataTransfer?.getData("text/uri-list") || "";
  if (uriListRaw) {
    for (const line of uriListRaw.split(/\r?\n/)) {
      const trimmed = line.trim();
      if (!trimmed || trimmed.startsWith("#")) continue;
      const localPath = normalizeFileUrlToPath(trimmed);
      if (localPath) {
        paths.push(localPath);
      }
    }
  }

  const files = Array.from(event.dataTransfer?.files || []);
  for (const file of files) {
    if (file.type.startsWith("image/")) continue;
    if (file.path) paths.push(file.path);
  }

  return Array.from(new Set(paths));
}

function handleImageFiles(files) {
  if (!files || !files.length) return;

  for (const file of files) {
    if (!file.type.startsWith("image/")) continue;
    if (file.size > MAX_IMAGE_SIZE_BYTES) {
      alert("图片超过 50MB，已拒绝上传。");
      continue;
    }
    const reader = new FileReader();
    reader.onload = () => {
      addImageMemo(reader.result);
    };
    reader.readAsDataURL(file);
  }
}

function bindDragUpload() {
  const dragTargets = ["dragenter", "dragover", "dragleave", "drop"];
  for (const type of dragTargets) {
    contentEl.addEventListener(type, (event) => {
      event.preventDefault();
      event.stopPropagation();
    });
  }

  contentEl.addEventListener("dragenter", () => {
    contentEl.classList.add("dragover");
  });

  contentEl.addEventListener("dragleave", (event) => {
    if (event.relatedTarget && contentEl.contains(event.relatedTarget)) return;
    contentEl.classList.remove("dragover");
  });

  contentEl.addEventListener("drop", (event) => {
    contentEl.classList.remove("dragover");

    const files = Array.from(event.dataTransfer?.files || []);
    for (const file of files) {
      if (file.type.startsWith("image/")) {
        handleImageFiles([file]);
      }
    }

    const paths = extractDropFilePaths(event);
    for (const filePath of paths) {
      addFileMemo(filePath);
    }
  });
}

window.handleNativeFileDrop = (localPaths) => {
  if (!Array.isArray(localPaths)) return;
  for (const rawPath of localPaths) {
    if (typeof rawPath !== "string" || !rawPath) continue;
    const lower = rawPath.toLowerCase();
    if (lower.endsWith(".png") || lower.endsWith(".jpg") || lower.endsWith(".jpeg") || lower.endsWith(".bmp") || lower.endsWith(".gif") || lower.endsWith(".webp")) {
      continue;
    }
    addFileMemo(rawPath);
  }
};

function escapeHtml(text) {
  return text
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function addMemo() {
  const text = input.value.trim();
  if (!text) return;
  memos.unshift({ type: "text", text });
  input.value = "";
  render();
  persistTodos();
  input.focus();
}

function addImageMemo(dataUrl) {
  if (!dataUrl) return;
  memos.unshift({ type: "image", src: dataUrl });
  render();
  persistTodos();
}

function clearAllTodos() {
  memos.splice(0, memos.length);
  render();
  if (capsuleBridge) {
    capsuleBridge.clearTodos();
  }
}

function tryPasteImage(event) {
  const items = event.clipboardData?.items;
  if (!items || !items.length) return;

  for (const item of items) {
    if (!item.type.startsWith("image/")) continue;
    const file = item.getAsFile();
    if (!file) continue;
    if (file.size > MAX_IMAGE_SIZE_BYTES) {
      event.preventDefault();
      alert("图片超过 50MB，已拒绝上传。");
      break;
    }

    event.preventDefault();
    const reader = new FileReader();
    reader.onload = () => {
      addImageMemo(reader.result);
    };
    reader.readAsDataURL(file);
    break;
  }
}

function initBridge() {
  if (typeof qt === "undefined" || !qt.webChannelTransport) {
    return;
  }

  new QWebChannel(qt.webChannelTransport, (channel) => {
    capsuleBridge = channel.objects.capsuleBridge;
    capsuleBridge.loadTodos((payload) => {
      hydrateTodos(payload);
    });
  });
}

function isPointOnInteractiveControl(target) {
  return !!target.closest("button, input, textarea, select");
}

function bindDrag() {
  capsuleEl.addEventListener("mousedown", (event) => {
    if (event.button !== 0 || !capsuleBridge) return;
    if (capsuleEl.classList.contains("expanded")) return;
    if (isPointOnInteractiveControl(event.target)) return;
    capsuleBridge.dragStart(event.screenX, event.screenY);
  });

  window.addEventListener("mousemove", (event) => {
    if (!capsuleBridge) return;
    capsuleBridge.dragMove(event.screenX, event.screenY);
  });

  window.addEventListener("mouseup", () => {
    if (!capsuleBridge) return;
    capsuleBridge.dragEnd();
  });
}

toggleBtn.addEventListener("click", () => {
  if (capsuleBridge) {
    capsuleBridge.toggleExpand();
  }
});

addBtn.addEventListener("click", addMemo);
voiceBtn.addEventListener("click", toggleVoiceInput);
clearBtn.addEventListener("click", clearAllTodos);
input.addEventListener("keydown", (event) => {
  if (event.key === "Enter") addMemo();
});
contentEl.addEventListener("paste", tryPasteImage);

listEl.addEventListener("click", (event) => {
  if (event.target instanceof HTMLImageElement && event.target.classList.contains("memo-image")) {
    if (capsuleBridge) {
      capsuleBridge.openImageSource(event.target.currentSrc || event.target.src);
    }
    return;
  }

  if (event.target instanceof HTMLButtonElement && event.target.classList.contains("file-link")) {
    if (capsuleBridge) {
      capsuleBridge.openFileLocation(event.target.dataset.path || "");
    }
    return;
  }

  if (!(event.target instanceof HTMLButtonElement)) return;
  const idx = Number(event.target.dataset.idx);
  if (!Number.isNaN(idx)) {
    memos.splice(idx, 1);
    render();
    persistTodos();
  }
});

window.setExpandedState = (expanded) => {
  capsuleEl.classList.toggle("expanded", expanded);
  contentEl.classList.toggle("expanded", expanded);
  stateLabel.textContent = expanded ? "正在记录" : "点击展开";
  toggleBtn.textContent = expanded ? "收起" : "展开";
};

initBridge();
bindDrag();
bindDragUpload();
setVoiceButtonState(false, "语音输入");
render();

window.addEventListener("beforeunload", () => {
  if (capsuleBridge && voiceListening) {
    capsuleBridge.stopVoiceInput();
  }
});
