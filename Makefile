# Makefile for QEMU.

GENERATED_HEADERS = config-host.h trace.h

ifneq ($(wildcard config-host.mak),)
# Put the all: rule here so that config-host.mak can contain dependencies.
all: build-all
include config-host.mak
include $(SRC_PATH)/rules.mak
config-host.mak: $(SRC_PATH)/configure
	@echo $@ is out-of-date, running configure
	@sed -n "/.*Configured with/s/[^:]*: //p" $@ | sh
else
config-host.mak:
	@echo "Please call configure before running make!"
	@exit 1
endif

# Don't try to regenerate Makefile or configure
# We don't generate any of them
Makefile: ;
configure: ;

.PHONY: all clean cscope distclean doc dvi html \
	info install install-doc install-tools \
	pdf recurse-all speed tar tarbin test tools build-all

$(call set-vpath, $(SRC_PATH):$(SRC_PATH)/hw)

LIBS+=-lz $(LIBS_TOOLS)

DOCS=qemu-doc.html qemu-tech.html qemu.1 qemu-img.1 qemu-nbd.8 QMP/qmp-commands.txt

SUBDIR_MAKEFLAGS=$(if $(V),,--no-print-directory)
SUBDIR_DEVICES_MAK=$(patsubst %, %/config-devices.mak, $(TARGET_DIRS))

config-all-devices.mak: $(SUBDIR_DEVICES_MAK)
	$(call quiet-command,cat $(SUBDIR_DEVICES_MAK) | grep =y | sort -u > $@,"  GEN   $@")

%/config-devices.mak: default-configs/%.mak
	$(call quiet-command,cat $< > $@.tmp, "  GEN   $@")
	@if test -f $@; then \
	  if cmp -s $@.old $@; then \
	    if ! cmp -s $@ $@.tmp; then \
	      mv $@.tmp $@; \
	      cp -p $@ $@.old; \
	    fi; \
	  else \
	    if test -f $@.old; then \
	      echo "WARNING: $@ (user modified) out of date.";\
	    else \
	      echo "WARNING: $@ out of date.";\
	    fi; \
	    echo "Run \"make defconfig\" to regenerate."; \
	    rm $@.tmp; \
	  fi; \
	 else \
	  mv $@.tmp $@; \
	  cp -p $@ $@.old; \
	 fi

defconfig:
	rm -f config-all-devices.mak $(SUBDIR_DEVICES_MAK)

-include config-all-devices.mak

build-all: recurse-all

ifdef BUILD_DOCS
build-all: doc
endif

ifdef BUILD_TOOLS
build-all: tools
endif

doc: $(DOCS)
tools: $(TOOLS)

config-host.h: config-host.h-timestamp
config-host.h-timestamp: config-host.mak

SUBDIR_RULES=$(patsubst %,subdir-%, $(TARGET_DIRS))

subdir-%: $(GENERATED_HEADERS)
	$(call quiet-command,$(MAKE) $(SUBDIR_MAKEFLAGS) -C $* V="$(V)" TARGET_DIR="$*/" all,)

ifneq ($(wildcard config-host.mak),)
include $(SRC_PATH)/Makefile.objs
endif

$(common-obj-y): $(GENERATED_HEADERS)
$(filter %-softmmu,$(SUBDIR_RULES)): $(trace-obj-y) $(common-obj-y) subdir-libdis

$(filter %-user,$(SUBDIR_RULES)): $(GENERATED_HEADERS) $(trace-obj-y) subdir-libdis-user subdir-libuser

ROMSUBDIR_RULES=$(patsubst %,romsubdir-%, $(ROMS))
romsubdir-%:
	$(call quiet-command,$(MAKE) $(SUBDIR_MAKEFLAGS) -C pc-bios/$* V="$(V)" TARGET_DIR="$*/",)

ALL_SUBDIRS=$(TARGET_DIRS) $(patsubst %,pc-bios/%, $(ROMS))

recurse-all: $(SUBDIR_RULES) $(ROMSUBDIR_RULES)

audio/audio.o audio/fmodaudio.o: QEMU_CFLAGS += $(FMOD_CFLAGS)

QEMU_CFLAGS+=$(CURL_CFLAGS)

ui/cocoa.o: ui/cocoa.m

ui/sdl.o audio/sdlaudio.o ui/sdl_zoom.o baum.o: QEMU_CFLAGS += $(SDL_CFLAGS)

ui/vnc.o: QEMU_CFLAGS += $(VNC_TLS_CFLAGS)

bt-host.o: QEMU_CFLAGS += $(BLUEZ_CFLAGS)

trace.h: trace.h-timestamp
trace.h-timestamp: $(SRC_PATH)/trace-events config-host.mak
	$(call quiet-command,sh $(SRC_PATH)/tracetool --$(TRACE_BACKEND) -h < $< > $@,"  GEN   trace.h")
	@cmp -s $@ trace.h || cp $@ trace.h

trace.c: trace.c-timestamp
trace.c-timestamp: $(SRC_PATH)/trace-events config-host.mak
	$(call quiet-command,sh $(SRC_PATH)/tracetool --$(TRACE_BACKEND) -c < $< > $@,"  GEN   trace.c")
	@cmp -s $@ trace.c || cp $@ trace.c

trace.o: trace.c $(GENERATED_HEADERS)

simpletrace.o: simpletrace.c $(GENERATED_HEADERS)

version.o: $(SRC_PATH)/version.rc config-host.mak
	$(call quiet-command,$(WINDRES) -I. -o $@ $<,"  RC    $(TARGET_DIR)$@")

version-obj-$(CONFIG_WIN32) += version.o
######################################################################

qemu-img.o: qemu-img-cmds.h
qemu-img.o qemu-tool.o qemu-nbd.o qemu-io.o: $(GENERATED_HEADERS)

qemu-img$(EXESUF): qemu-img.o qemu-tool.o qemu-error.o $(trace-obj-y) $(block-obj-y) $(qobject-obj-y) $(version-obj-y)

qemu-nbd$(EXESUF): qemu-nbd.o qemu-tool.o qemu-error.o $(trace-obj-y) $(block-obj-y) $(qobject-obj-y) $(version-obj-y)

qemu-io$(EXESUF): qemu-io.o cmd.o qemu-tool.o qemu-error.o $(trace-obj-y) $(block-obj-y) $(qobject-obj-y) $(version-obj-y)

qemu-img-cmds.h: $(SRC_PATH)/qemu-img-cmds.hx
	$(call quiet-command,sh $(SRC_PATH)/hxtool -h < $< > $@,"  GEN   $@")

check-qint.o check-qstring.o check-qdict.o check-qlist.o check-qfloat.o check-qjson.o: $(GENERATED_HEADERS)

check-qint: check-qint.o qint.o qemu-malloc.o
check-qstring: check-qstring.o qstring.o qemu-malloc.o
check-qdict: check-qdict.o qdict.o qfloat.o qint.o qstring.o qbool.o qemu-malloc.o qlist.o
check-qlist: check-qlist.o qlist.o qint.o qemu-malloc.o
check-qfloat: check-qfloat.o qfloat.o qemu-malloc.o
check-qjson: check-qjson.o qfloat.o qint.o qdict.o qstring.o qlist.o qbool.o qjson.o json-streamer.o json-lexer.o json-parser.o qemu-malloc.o

clean:
# avoid old build problems by removing potentially incorrect old files
	rm -f config.mak op-i386.h opc-i386.h gen-op-i386.h op-arm.h opc-arm.h gen-op-arm.h
	rm -f *.o *.d *.a $(TOOLS) TAGS cscope.* *.pod *~ */*~
	rm -f slirp/*.o slirp/*.d audio/*.o audio/*.d block/*.o block/*.d net/*.o net/*.d fsdev/*.o fsdev/*.d ui/*.o ui/*.d
	rm -f qemu-img-cmds.h
	rm -f trace.c trace.h trace.c-timestamp trace.h-timestamp
	$(MAKE) -C tests clean
	for d in $(ALL_SUBDIRS) libhw32 libhw64 libuser libdis libdis-user; do \
	if test -d $$d; then $(MAKE) -C $$d $@ || exit 1; fi; \
        done

distclean: clean
	rm -f config-host.mak config-host.h* config-host.ld $(DOCS) qemu-options.texi qemu-img-cmds.texi qemu-monitor.texi
	rm -f qemu-options.def
	rm -f config-all-devices.mak
	rm -f roms/seabios/config.mak roms/vgabios/config.mak
	rm -f qemu-doc.info qemu-doc.aux qemu-doc.cp qemu-doc.dvi qemu-doc.fn qemu-doc.info qemu-doc.ky qemu-doc.log qemu-doc.pdf qemu-doc.pg qemu-doc.toc qemu-doc.tp qemu-doc.vr
	rm -f qemu-tech.info qemu-tech.aux qemu-tech.cp qemu-tech.dvi qemu-tech.fn qemu-tech.info qemu-tech.ky qemu-tech.log qemu-tech.pdf qemu-tech.pg qemu-tech.toc qemu-tech.tp qemu-tech.vr
	for d in $(TARGET_DIRS) libhw32 libhw64 libuser libdis libdis-user; do \
	rm -rf $$d || exit 1 ; \
        done

KEYMAPS=da     en-gb  et  fr     fr-ch  is  lt  modifiers  no  pt-br  sv \
ar      de     en-us  fi  fr-be  hr     it  lv  nl         pl  ru     th \
common  de-ch  es     fo  fr-ca  hu     ja  mk  nl-be      pt  sl     tr

ifdef INSTALL_BLOBS
BLOBS=bios.bin vgabios.bin vgabios-cirrus.bin ppc_rom.bin \
openbios-sparc32 openbios-sparc64 openbios-ppc \
gpxe-eepro100-80861209.rom \
gpxe-eepro100-80861229.rom \
pxe-e1000.bin \
pxe-ne2k_pci.bin pxe-pcnet.bin \
pxe-rtl8139.bin pxe-virtio.bin \
bamboo.dtb petalogix-s3adsp1800.dtb \
multiboot.bin linuxboot.bin \
s390-zipl.rom
else
BLOBS=
endif

install-doc: doc
	$(INSTALL_DIR) "$(DESTDIR)$(docdir)"
	$(INSTALL_DATA) qemu-doc.html  qemu-tech.html "$(DESTDIR)$(docdir)"
ifdef CONFIG_POSIX
	$(INSTALL_DIR) "$(DESTDIR)$(mandir)/man1"
	$(INSTALL_DATA) qemu.1 qemu-img.1 "$(DESTDIR)$(mandir)/man1"
	$(INSTALL_DIR) "$(DESTDIR)$(mandir)/man8"
	$(INSTALL_DATA) qemu-nbd.8 "$(DESTDIR)$(mandir)/man8"
endif

install-sysconfig:
	$(INSTALL_DIR) "$(DESTDIR)$(sysconfdir)/qemu"
	$(INSTALL_DATA) $(SRC_PATH)/sysconfigs/target/target-x86_64.conf "$(DESTDIR)$(sysconfdir)/qemu"

install-tools: tools

install: all $(if $(BUILD_DOCS),install-doc) $(if $(BUILD_TOOLS),install-tools) install-sysconfig
	$(INSTALL_DIR) "$(DESTDIR)$(bindir)"
ifneq ($(TOOLS),)
	$(INSTALL_PROG) $(STRIP_OPT) $(TOOLS) "$(DESTDIR)$(bindir)"
endif
ifneq ($(BLOBS),)
	$(INSTALL_DIR) "$(DESTDIR)$(datadir)"
	set -e; for x in $(BLOBS); do \
		$(INSTALL_DATA) $(SRC_PATH)/pc-bios/$$x "$(DESTDIR)$(datadir)"; \
	done
endif
	$(INSTALL_DIR) "$(DESTDIR)$(datadir)/keymaps"
	set -e; for x in $(KEYMAPS); do \
		$(INSTALL_DATA) $(SRC_PATH)/pc-bios/keymaps/$$x "$(DESTDIR)$(datadir)/keymaps"; \
	done
	for d in $(TARGET_DIRS); do \
	$(MAKE) -C $$d $@ || exit 1 ; \
        done

# various test targets
test speed: all
	$(MAKE) -C tests $@

.PHONY: TAGS
TAGS:
	find "$(SRC_PATH)" -name '*.[hc]' -print0 | xargs -0 etags

cscope:
	rm -f ./cscope.*
	find . -name "*.[ch]" -print | sed 's,^\./,,' > ./cscope.files
	cscope -b

# documentation
MAKEINFO=makeinfo
MAKEINFOFLAGS=--no-headers --no-split --number-sections
TEXIFLAG=$(if $(V),,--quiet)
%.dvi: %.texi
	$(call quiet-command,texi2dvi $(TEXIFLAG) -I . $<,"  GEN   $@")

%.html: %.texi
	$(call quiet-command,$(MAKEINFO) $(MAKEINFOFLAGS) --html $< -o $@, \
	"  GEN   $@")

%.info: %.texi
	$(call quiet-command,$(MAKEINFO) $< -o $@,"  GEN   $@")

%.pdf: %.texi
	$(call quiet-command,texi2pdf $(TEXIFLAG) -I . $<,"  GEN   $@")

qemu-options.texi: $(SRC_PATH)/qemu-options.hx
	$(call quiet-command,sh $(SRC_PATH)/hxtool -t < $< > $@,"  GEN   $@")

qemu-monitor.texi: $(SRC_PATH)/hmp-commands.hx
	$(call quiet-command,sh $(SRC_PATH)/hxtool -t < $< > $@,"  GEN   $@")

QMP/qmp-commands.txt: $(SRC_PATH)/qmp-commands.hx
	$(call quiet-command,sh $(SRC_PATH)/hxtool -q < $< > $@,"  GEN   $@")

qemu-img-cmds.texi: $(SRC_PATH)/qemu-img-cmds.hx
	$(call quiet-command,sh $(SRC_PATH)/hxtool -t < $< > $@,"  GEN   $@")

qemu.1: qemu-doc.texi qemu-options.texi qemu-monitor.texi
	$(call quiet-command, \
	  perl -Ww -- $(SRC_PATH)/texi2pod.pl $< qemu.pod && \
	  pod2man --section=1 --center=" " --release=" " qemu.pod > $@, \
	  "  GEN   $@")

qemu-img.1: qemu-img.texi qemu-img-cmds.texi
	$(call quiet-command, \
	  perl -Ww -- $(SRC_PATH)/texi2pod.pl $< qemu-img.pod && \
	  pod2man --section=1 --center=" " --release=" " qemu-img.pod > $@, \
	  "  GEN   $@")

qemu-nbd.8: qemu-nbd.texi
	$(call quiet-command, \
	  perl -Ww -- $(SRC_PATH)/texi2pod.pl $< qemu-nbd.pod && \
	  pod2man --section=8 --center=" " --release=" " qemu-nbd.pod > $@, \
	  "  GEN   $@")

dvi: qemu-doc.dvi qemu-tech.dvi
html: qemu-doc.html qemu-tech.html
info: qemu-doc.info qemu-tech.info
pdf: qemu-doc.pdf qemu-tech.pdf

qemu-doc.dvi qemu-doc.html qemu-doc.info qemu-doc.pdf: \
	qemu-img.texi qemu-nbd.texi qemu-options.texi \
	qemu-monitor.texi qemu-img-cmds.texi

VERSION ?= $(shell cat VERSION)
FILE = qemu-$(VERSION)

ifdef CONFIG_WIN32
arm-softmmu/qemu-system-arm.exe: subdir-arm-softmmu
cris-softmmu/qemu-system-cris.exe: subdir-cris-softmmu
i386-softmmu/qemu.exe: subdir-i386-softmmu
m68k-softmmu/qemu-system-m68k.exe: subdir-m68k-softmmu
mips64el-softmmu/qemu-system-mips64el.exe: subdir-mips64el-softmmu
mips64-softmmu/qemu-system-mips64.exe: subdir-mips64-softmmu
mipsel-softmmu/qemu-system-mipsel.exe: subdir-mipsel-softmmu
mips-softmmu/qemu-system-mips.exe: subdir-mips-softmmu
ppc64-softmmu/qemu-system-ppc64.exe: subdir-ppc64-softmmu
ppcemb-softmmu/qemu-system-ppcemb.exe: subdir-ppcemb-softmmu
ppc-softmmu/qemu-system-ppc.exe: subdir-ppc-softmmu
sh4eb-softmmu/qemu-system-sh4eb.exe: subdir-sh4eb-softmmu
sh4-softmmu/qemu-system-sh4.exe: subdir-sh4-softmmu
sparc-softmmu/qemu-system-sparc.exe: subdir-sparc-softmmu
x86_64-softmmu/qemu-system-x86_64.exe: subdir-x86_64-softmmu

EXE_FILES :=

ifneq (,$(findstring arm-softmmu,$(TARGET_DIRS)))
EXE_FILES += arm-softmmu/qemu-system-arm.exe
endif
ifneq (,$(findstring cris-softmmu,$(TARGET_DIRS)))
EXE_FILES += cris-softmmu/qemu-system-cris.exe
endif
ifneq (,$(findstring i386-softmmu,$(TARGET_DIRS)))
EXE_FILES += i386-softmmu/qemu.exe
endif
ifneq (,$(findstring m68k-softmmu,$(TARGET_DIRS)))
EXE_FILES += m68k-softmmu/qemu-system-m68k.exe
endif
ifneq (,$(findstring mips64el-softmmu,$(TARGET_DIRS)))
EXE_FILES += mips64el-softmmu/qemu-system-mips64el.exe
endif
ifneq (,$(findstring mips64-softmmu,$(TARGET_DIRS)))
EXE_FILES += mips64-softmmu/qemu-system-mips64.exe
endif
ifneq (,$(findstring mipsel-softmmu,$(TARGET_DIRS)))
EXE_FILES += mipsel-softmmu/qemu-system-mipsel.exe
endif
ifneq (,$(findstring mips-softmmu,$(TARGET_DIRS)))
EXE_FILES += mips-softmmu/qemu-system-mips.exe
endif
ifneq (,$(findstring ppc64-softmmu,$(TARGET_DIRS)))
EXE_FILES += ppc64-softmmu/qemu-system-ppc64.exe
endif
ifneq (,$(findstring ppcemb-softmmu,$(TARGET_DIRS)))
EXE_FILES += ppcemb-softmmu/qemu-system-ppcemb.exe
endif
ifneq (,$(findstring ppc-softmmu,$(TARGET_DIRS)))
EXE_FILES += ppc-softmmu/qemu-system-ppc.exe
endif
ifneq (,$(findstring sh4eb-softmmu,$(TARGET_DIRS)))
EXE_FILES += sh4eb-softmmu/qemu-system-sh4eb.exe
endif
ifneq (,$(findstring sh4-softmmu,$(TARGET_DIRS)))
EXE_FILES += sh4-softmmu/qemu-system-sh4.exe
endif
ifneq (,$(findstring sparc-softmmu,$(TARGET_DIRS)))
EXE_FILES += sparc-softmmu/qemu-system-sparc.exe
endif
ifneq (,$(findstring x86_64-softmmu,$(TARGET_DIRS)))
EXE_FILES += x86_64-softmmu/qemu-system-x86_64.exe
endif

ifdef CONFIG_INSTALLER
qemu-setup.exe: $(SRC_PATH)/qemu.nsi qemu-img.exe $(EXE_FILES)
	makensis -NOCD \
		-DSRC_PATH="$(SRC_PATH)" \
		-DEXE_FILES="$(subst /,\\,$(EXE_FILES))" \
		-V2 $(SRC_PATH)/qemu.nsi
endif # CONFIG_INSTALLER
endif # CONFIG_WIN

# tar release (use 'make -k tar' on a checkouted tree)
tar:
	rm -rf /tmp/$(FILE)
	cp -r . /tmp/$(FILE)
	cd /tmp && tar zcvf ~/$(FILE).tar.gz $(FILE) --exclude CVS --exclude .git --exclude .svn
	rm -rf /tmp/$(FILE)

SYSTEM_TARGETS=$(filter %-softmmu,$(TARGET_DIRS))
SYSTEM_PROGS=$(patsubst qemu-system-i386,qemu, \
             $(patsubst %-softmmu,qemu-system-%, \
             $(SYSTEM_TARGETS)))

USER_TARGETS=$(filter %-user,$(TARGET_DIRS))
USER_PROGS=$(patsubst %-bsd-user,qemu-%, \
           $(patsubst %-darwin-user,qemu-%, \
           $(patsubst %-linux-user,qemu-%, \
           $(USER_TARGETS))))

# generate a binary distribution
tarbin:
	cd / && tar zcvf ~/qemu-$(VERSION)-$(ARCH).tar.gz \
	$(patsubst %,$(bindir)/%, $(SYSTEM_PROGS)) \
	$(patsubst %,$(bindir)/%, $(USER_PROGS)) \
	$(bindir)/qemu-img \
	$(bindir)/qemu-nbd \
	$(datadir)/bios.bin \
	$(datadir)/vgabios.bin \
	$(datadir)/vgabios-cirrus.bin \
	$(datadir)/ppc_rom.bin \
	$(datadir)/openbios-sparc32 \
	$(datadir)/openbios-sparc64 \
	$(datadir)/openbios-ppc \
	$(datadir)/pxe-ne2k_pci.bin \
	$(datadir)/pxe-rtl8139.bin \
	$(datadir)/pxe-pcnet.bin \
	$(datadir)/pxe-e1000.bin \
	$(docdir)/qemu-doc.html \
	$(docdir)/qemu-tech.html \
	$(mandir)/man1/qemu.1 \
	$(mandir)/man1/qemu-img.1 \
	$(mandir)/man8/qemu-nbd.8

# Include automatically generated dependency files
-include $(wildcard *.d audio/*.d slirp/*.d block/*.d net/*.d ui/*.d)
