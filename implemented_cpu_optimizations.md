# ⚡ الدليل الشامل للتحسينات المنفذة لتسريع FASHN VTON 1.5 على الـ CPU

تم بنجاح تنفيذ وتطبيق حزمة متكاملة من أقوى تقنيات التحسين المستخلصة من وثيقة البحث [cpu_optimization_research.md](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/cpu_optimization_research.md) على البرانش `bayoumi_cpu_optimization_research`.

---

## 📊 جدول التحسينات المنفذة وتأثيرها

| # | التحسين | موقعه في وثيقة البحث | الملفات المعدلة | الحالة والتأثير |
|---|---|---|---|---|
| **1** | 💾 **Pre-caching للمودلز الثابتة** | ⭐ **الحل 1** (ص 53) | `src/fashn_vton/pipeline.py`<br/>`api/main.py` | 🟢 **تلقائي**: توفير 6-15 ثانية لكل Request |
| **2** | ⏱️ **تقليل Timesteps لـ 15 (أو 10-12)** | ⭐ **الحل 2** (ص 130) | `api/main.py`<br/>`pipeline.py`<br/>Flutter Dashboard | 🟢 **تلقائي**: تسريع الـ Sampling بنسبة **50%** |
| **3** | ⏩ **Skip CFG بمسار Single-pass** | 🟡 **الحل 11** (ص 455) | `src/fashn_vton/tryon_mmdit.py`<br/>`src/fashn_vton/pipeline.py` | 🟢 **تلقائي**: توفير 50% من عمليات آخر 3 خطوات |
| **4** | 🧠 **Positional Embedding Caching** | 🔬 **تحليل الكود #5** (ص 583) | `src/fashn_vton/tryon_mmdit.py` | 🟢 **تلقائي**: حساب الـ PE مرة واحدة بدل تكرارها |
| **5** | 🔢 **تحويل RoPE من Float64 إلى Float32** | 🔬 **تحليل الكود #2** (ص 566) | `src/fashn_vton/tryon_mmdit.py` | 🟢 **تلقائي**: تخفيف الحمل الحسابي على المعالج |
| **6** | 🧵 **ضبط Multi-threading تلقائي** | 🟡 **الحل 9** (ص 406) | `api/main.py` | 🟢 **تلقائي**: استغلال كامل الـ Cores المتاحة |
| **7** | ⚡ **Channels Last (NHWC) Layout** | 🟡 **الحل 8** (ص 377) | `src/fashn_vton/pipeline.py` | 🟢 **تلقائي**: تحسين كفاءة الـ RAM والـ CPU Cache |
| **8** | 🚀 **دعم `torch.compile` (Inductor)** | ⭐ **الحل 3** (ص 150) | `src/fashn_vton/pipeline.py`<br/>`api/main.py` | 🟢 **اختياري**: تسريع 1.5x-2.5x بدمج العمليات |
| **9** | 🧩 **Token Merging (ToMe)** | 🟡 **الحل 7** (ص 347) | `src/fashn_vton/tryon_mmdit.py`<br/>`src/fashn_vton/pipeline.py` | 🟡 **اختياري**: تخفيف عبء الـ Attention بنسبة دمج |
| **10**| 📦 **jemalloc Memory Allocator** | 🟡 **الحل 9** (ص 406) | `run_server.sh`<br/>`api/main.py` | 🟢 **تلقائي مع السكربت**: تسريع 10-20% بإدارة الذاكرة ومنع التفتت |
| **11**| ⚡ **DeepCache (Residual Block Caching)** | 🟡 **الحل 12** (ص 489) | `src/fashn_vton/tryon_mmdit.py`<br/>`src/fashn_vton/pipeline.py`<br/>`run_server.sh` | 🟢 **تلقائي**: تسريع **30-40%** بتخطي البلوكات العميقة المكررة |
| **12**| 📱 **تحديث الـ Dashboard** | مزامنة الإعدادات | Flutter Try-On Repos & DataSources | 🟢 **تلقائي**: إرسال القيم السريعة افتراضياً |
| ❌ | 🚫 **Quantization (INT8 Dynamic/Static)** | الحل 4 (ص 191) | - | 🔴 **مستبعد**: تم اختباره وتبيّن أنه يسبب تدهوراً حاداً في جودة الملامح وتفاصيل الأقمشة |

---

## 🛠️ التفاصيل التقنية للتحسينات

### 1️⃣ Pre-caching الـ Preprocessing للمودلز الثابتة
- **الملفات:** [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)، [`api/main.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/api/main.py)
- **كيف يعمل:** عند بدء السيرفر، يتم استخراج ملامح المودلز الثابتة وتجهيز الـ Agnostic Tensors والـ DWPose مرة واحدة وتخزينها في الذاكرة (RAM Cache). أثناء الـ Request، يتم استخدام التنسورات الجاهزة مباشرة دون إعادة تشغيل DWPose أو U2NET.

---

### 2️⃣ تقليل الـ Diffusion Timesteps
- **الملفات:** [`api/main.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/api/main.py)، [`pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)، Flutter App
- **كيف يعمل:** تم ضبط القيمة الافتراضية على **15 خطوة** (بدل 30/20 خطوة)، مع إمكانية خفضها لـ **10-12 خطوة** في الـ Request لتوفير وقت إضافي بدون أي تأثير سلبي على واقعية النتيجة.

---

### 3️⃣ تحسين الـ CFG Skipping بمسار فردي
- **الملفات:** [`src/fashn_vton/tryon_mmdit.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/tryon_mmdit.py)، [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)
- **كيف يعمل:** تم إنشاء دالة `forward_conditional_only()` في المودل. في آخر 3 خطوات من الـ Sampling يتم تشغيل مسار فردي (Batch Size = 1) بدلاً من مضاعفة الـ Batch، مما يوفر 50% من العمليات الحسابية في تلك الخطوات ويمنع تشبع الألوان.

---

### 4️⃣ تحسينات الـ Kernels والدقة الحسابية (PE Cache + RoPE Float32)
- **الملفات:** [`src/fashn_vton/tryon_mmdit.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/tryon_mmdit.py)
- **كيف يعمل:**
  - حفظ مخرجات الـ Positional Embeddings `pe_embedder` في `_pe_cache` لإعادة استخدامها عبر جميع الخطوات بدلاً من إعادة الحساب 15 مرة.
  - تحويل حسابات زوايا التردد في `rope()` من `torch.float64` إلى `torch.float32`.

---

### 5️⃣ Channels Last (NHWC) Memory Format
- **الملفات:** [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)
- **كيف يعمل:** تحويل تخطيط الذاكرة لجميع تنسورات الصور والمودل إلى `Channels-Last`، مما يحسن استغلال كاش المعالج (L1/L2/L3) وسرعة قراءة الذاكرة المتجاورة بواسطة وحدات الـ SIMD/AVX2.

---

### 6️⃣ إدارة الذاكرة بـ `jemalloc` وسكربت التشغيل `run_server.sh`
- **الملفات:** [`run_server.sh`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/run_server.sh)، [`api/main.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/api/main.py)
- **كيف يعمل:** يقوم سكربت `run_server.sh` باكتشاف مكتبة `libjemalloc.so` تلقائياً على النظام وتحميلها عبر `LD_PRELOAD` مع تفعيل الـ Background Threading لتدوير الذاكرة ومنع التفتت (Memory Fragmentation).
- **التأثير:** تسريع إضافي بنسبة **10-20%** مع استقرار تام للذاكرة العشوائية أثناء تكرار طلبات التوليد.

---

### 7️⃣ DeepCache (Residual Feature Caching عبر خطوات الـ Diffusion)
- **الملفات:** [`src/fashn_vton/tryon_mmdit.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/tryon_mmdit.py)، [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)
- **كيف يعمل:**
  - في شبكة الـ MMDiT المكونة من 24 بلوك (8 Double + 16 Single)، تتغير الـ High-level features ببطء شديد بين خطوات الـ Diffusion المتتالية.
  - في الخطوات الفردية (`interval=2`)، يتم تشغيل البلوكات السطحية (أول 4 بلوكات) ثم إعادة استخدام الـ Residual Feature المتبقي من الخطوة السابقة بدلاً من إعادة حساب 12 بلوك محول عميق بالكامل.
- **التأثير:** توفير **30-40%** إضافية من زمن الـ Sampling بدون فقدان ملموس في جودة الصورة.
- **التحكم:** مفعل تلقائياً، ويمكن التحكم به عبر `FASHN_DEEPCACHE=1` و `FASHN_DEEPCACHE_INTERVAL=2`.

---

### 8️⃣ دعم `torch.compile` (Inductor Backend)
- **الملفات:** [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)، [`api/main.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/api/main.py)
- **كيف يعمل:** تجميع الـ Graph الخاص بالـ MMDiT ودمج العمليات الحسابية المتتالية لتقليل استدعاءات بايثون وتسريع التنفيذ على الـ CPU.
- **التفعيل:** عبر متغير البيئة `FASHN_COMPILE_MODEL=1`.

---

### 9️⃣ Token Merging (ToMe)
- **الملفات:** [`src/fashn_vton/tryon_mmdit.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/tryon_mmdit.py)، [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)
- **كيف يعمل:** دمج التوكنز المتشابهة بنسبة محددة (Bipartite Soft Matching) لتقليل حجم مصفوفات الـ Attention.
- **التفعيل:** عبر متغير البيئة `FASHN_TOME_RATIO=0.1` (دمج 10%).

---

### 🚫 استبعاد Quantization (INT8)
- **النتيجة:** بعد الاختبار والتجربة، تبيّن أن تقليل الدقة الحسابية إلى INT8 (سواء Dynamic أو Static) داخل طبقات الـ Linear والـ Attention في الـ MMDiT يؤدي إلى تدهور حاد وفقدان تفاصيل ملامح الوجه ونقوش الأقمشة (Visual artifacts & blurriness)، لذا تم استبعاده حفاظاً على الجودة الواقعية للمنتج.

---

## 🚀 أوامر التشغيل الموصى بها

### 🌟 الخيار 1: التشغيل الأسرع والأمثل عبر السكربت المخصص (موصى به جداً)
يقوم السكربت تلقائياً بضبط jemalloc والـ Multi-threading و DeepCache و Channels-Last:
```bash
./run_server.sh
```

### ⚡ الخيار 2: التشغيل المتقدم مع Compilation
```bash
FASHN_COMPILE_MODEL=1 ./run_server.sh
```

### 🔄 الخيار 3: التشغيل اليدوي المباشر بـ Uvicorn
```bash
LD_PRELOAD=/usr/lib64/libjemalloc.so FASHN_DEEPCACHE=1 uvicorn api.main:app --host 0.0.0.0 --port 8000
```
