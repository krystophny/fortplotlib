     ☒ ISSUE CONFIRMED: ForTTF k=-1.175, STB k≈0.447 for same pixel - investigate scanline                                                                                        [50/1861]
       buffer differences
     ☒ CRITICAL BUG FOUND: ForTTF debug shows final=0 but bitmap shows 221 - debug vs
       actual mismatch
     ☒ ROOT CAUSE CONFIRMED: ForTTF k=-1.175, STB k=+0.447 - completely different edge
       processing
     ☒ Deep dive: Compare STB vs ForTTF edge building step by step for character '$'
     ☒ BREAKTHROUGH: STB=39 vertices, ForTTF=41 vertices - glyph parsing differs
       fundamentally!
     ☒ PARTIAL FIX: Removed contour closing - now ForTTF=38 vs STB=39, but accuracy still
       89.36%
     ☐ WRONG ANALYSIS: All 3 contours close, not just contour 1 - need proper STB vertex
       extraction
     ☐ Compare STB vs ForTTF vertex extraction step by step to find exact difference
     ☐ Achieve 100% pixel-perfect accuracy

● My analysis was completely wrong. The debug shows that STB must be handling contour
  closing differently. Instead of guessing, I need to extract the actual vertices from STB
  and compare them line by line with ForTTF. Let me create a proper comparison:

● Write(test/forttf/test_stb_vertex_extraction.f90)
  ⎿  Wrote 107 lines to test/forttf/test_stb_vertex_extraction.f90
     program test_stb_vertex_extraction
         !! Extract actual STB vertices to compare with ForTTF step by step
         use test_forttf_utils
         use fortplot_stb_truetype
         use forttf
         use forttf_outline
         use forttf_types
         use iso_c_binding
         use, intrinsic :: iso_fortran_env, only: wp => real64
         implicit none
     … +97 lines (ctrl+r to expand)

● Bash(fpm test --target test_stb_vertex_extraction)
  ⎿  Error: <ERROR> Compilation failed for object "
     test_forttf_test_stb_vertex_extraction.f90.o "
     <ERROR> stopping due to failed compilation
     STOP 1

     [  0%] test_stb_vertex_extraction.f90
     [ 50%] test_stb_vertex_extraction.f90  done.

     test/forttf/test_stb_vertex_extraction.f90:42:31:

        42 |             num_stb_vertices = stb_get_codepoint_shape(stb_font, codepoint,
     stb_vertices)
     … +3 lines (ctrl+r to see all)

● Let me fix the function call to get STB vertices:
● Search(pattern: "stb_get_codepoint_shape.*interface", include: "*.f90")
  ⎿  Found 2 files (ctrl+r to expand)

● Search(pattern: "function stb_get_codepoint_shape", include: "*.f90")
  ⎿  Found 2 files (ctrl+r to expand)

● Read(src/fortplot_stb_truetype.f90)
  ⎿  Read 50 lines (ctrl+r to expand)

● Search(pattern: "stb_get_codepoint_shape.*bind", include: "*.f90")
  ⎿  Found 1 file (ctrl+r to expand)

● Read(src/fortplot_stb_truetype.f90)
  ⎿  Read 50 lines (ctrl+r to expand)

● Search(pattern: "stb_get_codepoint_shape", include: "*.f90")
  ⎿  Found 12 files (ctrl+r to expand)

● Read(test/forttf/test_glyph_vertex_comparison.f90)
  ⎿  Read 50 lines (ctrl+r to expand)

● I can see the correct pattern. Let me fix my test:

● Update(test/forttf/test_stb_vertex_extraction.f90)
  ⎿  Updated test/forttf/test_stb_vertex_extraction.f90 with 2 additions and 2 removals
       39                type(c_ptr) :: stb_vertices
       40                integer :: num_stb_vertices
       41
       42 -              num_stb_vertices = stb_get_codepoint_shape(stb_font, codepoint,
     stb_vertices)
          - _vertices)
       42 +              stb_vertices = stb_get_codepoint_shape(stb_font, codepoint,
     num_stb_vertices)
          + _vertices)
       43                write(*,'(A,I0,A)') 'STB extracted ', num_stb_vertices, '
     vertices'
       44
       45 -              if (num_stb_vertices > 0) then
       45 +              if (c_associated(stb_vertices) .and. num_stb_vertices > 0) then
       46                    call print_stb_vertices(stb_vertices, num_stb_vertices)
       47                    call stb_free_shape(stb_vertices)
       48                end if
