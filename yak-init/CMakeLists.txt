cmake_minimum_required(VERSION 3.31)

project(yak-init)

add_executable(init init.c)

install(TARGETS init RUNTIME DESTINATION bin)
