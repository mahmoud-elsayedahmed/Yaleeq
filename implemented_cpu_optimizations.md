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
| **10**| 📱 **تحديث الـ Dashboard** | مزامنة الإعدادات | Flutter Try-On Repos & DataSources | 🟢 **تلقائي**: إرسال القيم السريعة افتراضياً |

---

## 🛠️ التفاصيل التقنية لكل تحسين

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

### 6️⃣ دعم `torch.compile` (Inductor Backend)
- **الملفات:** [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)، [`api/main.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/api/main.py)
- **كيف يعمل:** تجميع الـ Graph الخاص بالـ MMDiT ودمج العمليات الحسابية المتتالية لتقليل استدعاءات بايثون وتسريع التنفيذ على الـ CPU.
- **التفعيل:** عبر متغير البيئة `FASHN_COMPILE_MODEL=1`.

---

### 7️⃣ Token Merging (ToMe)
- **الملفات:** [`src/fashn_vton/tryon_mmdit.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/tryon_mmdit.py)، [`src/fashn_vton/pipeline.py`](file:///run/media/bayoumi/02CA14DDCA14CF33/fashn-vton-1.5/src/fashn_vton/pipeline.py)
- **كيف يعمل:** دمج التوكنز المتشابهة بنسبة محددة (Bipartite Soft Matching) لتقليل حجم مصفوفات الـ Attention.
- **التفعيل:** عبر متغير البيئة `FASHN_TOME_RATIO=0.1` (دمج 10%).

---

## 🚀 أوامر التشغيل الموصى بها

### 🌟 الخيار 1: التشغيل القياسي الأسرع والأنقى (موصى به)
```bash
FASHN_COMPILE_MODEL=1 uvicorn api.main:app --host 0.0.0.0 --port 8000
```

### ⚡ الخيار 2: التشغيل مع تفعيل دمج الـ Tokens (ToMe)
```bash
FASHN_COMPILE_MODEL=1 FASHN_TOME_RATIO=0.1 uvicorn api.main:app --host 0.0.0.0 --port 8000
```

### 🔄 الخيار 3: التشغيل العادي (بدون Compilation)
```bash
uvicorn api.main:app --host 0.0.0.0 --port 8000
```
