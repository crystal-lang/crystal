SOURCES = $(shell find . -name '*.c')
OBJS = $(subst .c,.o,$(SOURCES))
TARGET = libext.a

all: $(TARGET)

$(TARGET): $(OBJS)
	ar -rcs $@ $^

clean:
	rm -f $(OBJS) $(TARGET)
