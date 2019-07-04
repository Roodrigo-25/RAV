_DIR   := .build
FF_VER := shared
_EXE   := untrunc
IS_RELEASE := 0

# make switching between ffmpeg versions easy
TARGET := $(firstword $(MAKECMDGOALS))
ifeq ($(TARGET), $(_EXE)-33)
  FF_VER := 3.3.9
  EXE := $(TARGET)
else ifeq ($(TARGET), $(_EXE)-34)
  FF_VER := 3.4.5
  EXE := $(TARGET)
else ifeq ($(TARGET), $(_EXE)-340)
  FF_VER := 3.4.0
  EXE := $(TARGET)
else ifeq ($(TARGET), $(_EXE)-41)
  FF_VER := 4.1
  EXE := $(TARGET)
endif

ifeq ($(FF_VER), shared)
  LDFLAGS += -lavformat -lavcodec -lavutil
  CXXFLAGS += -O3
else
  CXXFLAGS += -I./ffmpeg-$(FF_VER)
  LDFLAGS += -Lffmpeg-$(FF_VER)/libavformat -lavformat
  LDFLAGS += -Lffmpeg-$(FF_VER)/libavcodec -lavcodec
  LDFLAGS += -Lffmpeg-$(FF_VER)/libavutil -lavutil
  #LDFLAGS += -Lffmpeg-$(FF_VER)/libswscale/ -lswresample
  #LDFLAGS += -Lffmpeg-$(FF_VER)/libavresample -lavresample
  LDFLAGS += -lpthread -lz -lbz2 -lX11 -ldl -lva -lva-drm -lva-x11 -llzma -lvdpau
endif

CXXFLAGS += -std=c++11 -g

VER = $(shell test -d .git && which git >/dev/null 2>&1 && git describe --always --dirty --abbrev=7)
CPPFLAGS += -MMD -MP
CPPFLAGS += -DUNTR_VERSION=\"$(VER)\"

EXE ?= $(_EXE)
DIR := $(_DIR)_$(FF_VER)
SRC := $(wildcard *.cpp)
OBJ := $(SRC:%.cpp=$(DIR)/%.o)
DEP := $(OBJ:.o=.d)
FFDIR := ffmpeg-$(FF_VER)

NPROC = $(shell nproc)
NJOBS = $(shell echo $$(( $(NPROC) / 3)) )
ifeq ($(NJOBS), 0)
  NJOBS = 1
endif

.PHONY: all clean force


all: $(EXE)

$(FFDIR)/configure:
	@#read -p "Press [ENTER] if you agree to build ffmpeg-${FF_VER} now.. " input
	@echo "(info) downloading $(FFDIR) ..."
	wget -q --show-progress -O /tmp/$(FFDIR).tar.xz https://www.ffmpeg.org/releases/$(FFDIR).tar.xz
	tar xf /tmp/$(FFDIR).tar.xz

$(FFDIR)/config.asm: | $(FFDIR)/configure
	@echo "(info) please wait ..."
	cd $(FFDIR); ./configure --disable-doc --disable-programs \
	--disable-everything --enable-decoders --enable-demuxers --enable-protocol=file \
	--disable-avdevice --disable-swresample --disable-swscale --disable-avfilter --disable-postproc

$(FFDIR)/libavcodec/libavcodec.a: | $(FFDIR)/config.asm
	cat $(FFDIR)/Makefile
	$(MAKE) -C $(FFDIR) -j$(NJOBS)

$(FFDIR):

ifneq ($(FF_VER), shared)
$(FFDIR): | $(FFDIR)/libavcodec/libavcodec.a
endif

print_info: | $(FFDIR)
	@echo untrunc: $(VER)
	@echo ffmpeg: $(FF_VER)
	@echo

$(EXE): print_info $(OBJ)
	$(CXX) $(filter-out $<,$^) $(LDFLAGS) -o $@

# rebuild common.o if new version/CPPFLAGS
$(DIR)/cpp_flags: force
	@echo '$(CPPFLAGS)' | cmp -s - $@ || echo '$(CPPFLAGS)' > $@
common.o: $(DIR)/cpp_flags

$(DIR):
	mkdir $@

$(DIR)/%.o: %.cpp | $(DIR)
	$(CXX) $(CPPFLAGS) $(CXXFLAGS) -o $@ -c $<

-include $(DEP)

clean:
	$(RM) -r $(DIR)
	$(RM) $(EXE)

