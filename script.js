(() => {
  'use strict';

  const body = document.body;
  const intro = document.querySelector('#intro');
  const introVideo = document.querySelector('#intro-video');
  const skipIntro = document.querySelector('#skip-intro');
  const siteShell = document.querySelector('#site-shell');
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)');
  let introClosed = false;

  body.classList.add('intro-active');

  function closeIntro() {
    if (introClosed) return;
    introClosed = true;
    intro.classList.add('is-hidden');
    siteShell.classList.add('is-ready');
    body.classList.remove('intro-active');
    window.setTimeout(() => intro.setAttribute('aria-hidden', 'true'), 750);
  }

  skipIntro.addEventListener('click', closeIntro);
  introVideo.addEventListener('ended', closeIntro);
  introVideo.addEventListener('error', closeIntro);
  window.setTimeout(closeIntro, 11000);

  if (reducedMotion.matches) {
    introVideo.pause();
    window.setTimeout(closeIntro, 250);
  } else {
    const playAttempt = introVideo.play();
    if (playAttempt) playAttempt.catch(() => {
      introVideo.controls = true;
    });
  }

  const topbar = document.querySelector('.topbar');
  const menuToggle = document.querySelector('#menu-toggle');
  const nav = document.querySelector('#site-nav');

  function updateTopbar() {
    topbar.classList.toggle('is-scrolled', window.scrollY > 20);
  }
  updateTopbar();
  window.addEventListener('scroll', updateTopbar, { passive: true });

  menuToggle.addEventListener('click', () => {
    const isOpen = nav.classList.toggle('is-open');
    menuToggle.setAttribute('aria-expanded', String(isOpen));
    menuToggle.setAttribute('aria-label', isOpen ? 'Close navigation' : 'Open navigation');
  });
  nav.addEventListener('click', event => {
    if (event.target.closest('a')) {
      nav.classList.remove('is-open');
      menuToggle.setAttribute('aria-expanded', 'false');
    }
  });

  const reveals = document.querySelectorAll('.reveal');
  const revealObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        entry.target.classList.add('is-visible');
        revealObserver.unobserve(entry.target);
      }
    });
  }, { threshold: 0.12, rootMargin: '0px 0px -40px' });
  reveals.forEach((element, index) => {
    element.style.transitionDelay = `${Math.min((index % 4) * 70, 210)}ms`;
    revealObserver.observe(element);
  });

  const sectionLinks = [...document.querySelectorAll('.nav a')];
  const observedSections = sectionLinks
    .map(link => document.querySelector(link.getAttribute('href')))
    .filter(Boolean);
  const sectionObserver = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      if (!entry.isIntersecting) return;
      sectionLinks.forEach(link => {
        link.classList.toggle('is-active', link.getAttribute('href') === `#${entry.target.id}`);
      });
    });
  }, { rootMargin: '-30% 0px -60%' });
  observedSections.forEach(section => sectionObserver.observe(section));

  const cursorLight = document.querySelector('#cursor-light');
  if (window.matchMedia('(pointer:fine)').matches && !reducedMotion.matches) {
    document.addEventListener('pointermove', event => {
      cursorLight.style.left = `${event.clientX}px`;
      cursorLight.style.top = `${event.clientY}px`;
      cursorLight.style.opacity = '1';
    }, { passive: true });

    document.querySelectorAll('.tilt-card').forEach(card => {
      card.addEventListener('pointermove', event => {
        const rect = card.getBoundingClientRect();
        const x = (event.clientX - rect.left) / rect.width - 0.5;
        const y = (event.clientY - rect.top) / rect.height - 0.5;
        card.style.transform = `perspective(900px) rotateX(${-y * 7}deg) rotateY(${x * 9}deg) translateZ(5px)`;
      });
      card.addEventListener('pointerleave', () => {
        card.style.transform = '';
      });
    });
  }

  let audioContext;
  let soundEnabled = true;
  let lastHoverTime = 0;
  const soundToggle = document.querySelector('#sound-toggle');

  function getAudioContext() {
    if (!audioContext) {
      const AudioContext = window.AudioContext || window.webkitAudioContext;
      if (AudioContext) audioContext = new AudioContext();
    }
    if (audioContext?.state === 'suspended') audioContext.resume();
    return audioContext;
  }

  function tone(type) {
    if (!soundEnabled) return;
    const context = getAudioContext();
    if (!context) return;
    const now = context.currentTime;
    const oscillator = context.createOscillator();
    const gain = context.createGain();
    oscillator.type = type === 'click' ? 'square' : 'sine';
    oscillator.frequency.setValueAtTime(type === 'click' ? 190 : 520, now);
    oscillator.frequency.exponentialRampToValueAtTime(type === 'click' ? 440 : 720, now + (type === 'click' ? .055 : .025));
    gain.gain.setValueAtTime(0.0001, now);
    gain.gain.exponentialRampToValueAtTime(type === 'click' ? .032 : .011, now + .006);
    gain.gain.exponentialRampToValueAtTime(0.0001, now + (type === 'click' ? .08 : .04));
    oscillator.connect(gain).connect(context.destination);
    oscillator.start(now);
    oscillator.stop(now + .09);
  }

  document.addEventListener('pointerover', event => {
    const target = event.target.closest('.sound-target');
    if (!target || target.contains(event.relatedTarget)) return;
    const now = performance.now();
    if (now - lastHoverTime < 70) return;
    lastHoverTime = now;
    tone('hover');
  });
  document.addEventListener('click', event => {
    const target = event.target.closest('.sound-target, .tree-row, .copy-button');
    if (!target) return;
    tone('click');
    target.classList.remove('is-sounded');
    void target.offsetWidth;
    target.classList.add('is-sounded');
    window.setTimeout(() => target.classList.remove('is-sounded'), 220);
  });

  soundToggle.addEventListener('click', () => {
    soundEnabled = !soundEnabled;
    soundToggle.setAttribute('aria-pressed', String(soundEnabled));
    soundToggle.setAttribute('aria-label', soundEnabled ? 'Turn interface sounds off' : 'Turn interface sounds on');
    if (soundEnabled) tone('click');
  });

  const detailData = {
    config: ['config/', 'The central live-build definition: boot UI, build hooks, target filesystem content, and package selection.'],
    boot: ['bootloaders/isolinux/', 'Syslinux/Isolinux configuration for the branded live and failsafe boot options.'],
    hooks: ['hooks/', 'Non-interactive scripts that repair compatibility and customize the target system during a build.'],
    includes: ['includes.chroot/', 'Files copied directly into the live filesystem, including identity, desktop settings, icons, and backgrounds.'],
    packages: ['package-lists/', 'The source of truth for software installed into the current XFCE live image.'],
    auto: ['auto/config', 'Reproducible Ubuntu Noble, amd64, mirror, kernel, bootloader, and ISO options passed to live-build.'],
    resume: ['resume-build.sh', 'A narrowly scoped recovery helper for known interrupted bootstrap, chroot, and Syslinux build states.'],
    test: ['test-build.sh', 'Starts binary.hybrid.iso in QEMU with KVM, four virtual CPUs, and 4 GB of memory.']
  };
  const fileDetail = document.querySelector('#file-detail');
  document.querySelectorAll('.tree-row').forEach(row => {
    row.addEventListener('click', () => {
      document.querySelectorAll('.tree-row').forEach(item => item.classList.remove('is-selected'));
      row.classList.add('is-selected');
      const [title, copy] = detailData[row.dataset.detail];
      fileDetail.querySelector('h3').textContent = title;
      fileDetail.querySelector('p').textContent = copy;
    });
  });

  document.querySelectorAll('.copy-button').forEach(button => {
    button.addEventListener('click', async () => {
      const target = document.querySelector(`#${button.dataset.copyTarget}`);
      try {
        await navigator.clipboard.writeText(target.innerText);
        button.textContent = 'COPIED';
      } catch {
        button.textContent = 'SELECT TEXT';
      }
      window.setTimeout(() => button.textContent = 'COPY', 1800);
    });
  });
})();
