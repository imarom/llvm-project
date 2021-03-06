; NOTE: Assertions have been autogenerated by utils/update_test_checks.py UTC_ARGS: --function-signature --scrub-attributes
; RUN: opt -S -passes=attributor -aa-pipeline='basic-aa' -attributor-disable=false -attributor-max-iterations-verify -attributor-max-iterations=4 < %s | FileCheck %s
; PR36485
; musttail call result can't be replaced with a constant, unless the call can be removed

declare i32 @external()

define i8* @start(i8 %v) {
; CHECK-LABEL: define {{[^@]+}}@start
; CHECK-SAME: (i8 [[V:%.*]])
; CHECK-NEXT:    [[C1:%.*]] = icmp eq i8 [[V]], 0
; CHECK-NEXT:    br i1 [[C1]], label [[TRUE:%.*]], label [[FALSE:%.*]]
; CHECK:       true:
; CHECK-NEXT:    [[CA:%.*]] = musttail call i8* @side_effects(i8 [[V]])
; CHECK-NEXT:    ret i8* [[CA]]
; CHECK:       false:
; CHECK-NEXT:    [[C2:%.*]] = icmp eq i8 [[V]], 1
; CHECK-NEXT:    br i1 [[C2]], label [[C2_TRUE:%.*]], label [[C2_FALSE:%.*]]
; CHECK:       c2_true:
; CHECK-NEXT:    [[CA1:%.*]] = musttail call i8* @no_side_effects(i8 undef)
; CHECK-NEXT:    ret i8* [[CA1]]
; CHECK:       c2_false:
; CHECK-NEXT:    [[CA2:%.*]] = musttail call i8* @dont_zap_me(i8 undef)
; CHECK-NEXT:    ret i8* [[CA2]]
;
  %c1 = icmp eq i8 %v, 0
  br i1 %c1, label %true, label %false
true:
  ; FIXME: propagate the value information for %v
  %ca = musttail call i8* @side_effects(i8 %v)
  ret i8* %ca
false:
  %c2 = icmp eq i8 %v, 1
  br i1 %c2, label %c2_true, label %c2_false
c2_true:
  %ca1 = musttail call i8* @no_side_effects(i8 %v)
  ; FIXME: zap this call
  ret i8* %ca1
c2_false:
  %ca2 = musttail call i8* @dont_zap_me(i8 %v)
  ret i8* %ca2
}

define internal i8* @side_effects(i8 %v) {
; CHECK-LABEL: define {{[^@]+}}@side_effects
; CHECK-SAME: (i8 [[V:%.*]])
; CHECK-NEXT:    [[I1:%.*]] = call i32 @external()
; CHECK-NEXT:    [[CA:%.*]] = musttail call i8* @start(i8 [[V]])
; CHECK-NEXT:    ret i8* [[CA]]
;
  %i1 = call i32 @external()

  ; since this goes back to `start` the SCPP should be see that the return value
  ; is always `null`.
  ; The call can't be removed due to `external` call above, though.

  %ca = musttail call i8* @start(i8 %v)

  ; Thus the result must be returned anyway
  ret i8* %ca
}

define internal i8* @no_side_effects(i8 %v) readonly nounwind {
; CHECK-LABEL: define {{[^@]+}}@no_side_effects
; CHECK-SAME: (i8 [[V:%.*]])
; CHECK-NEXT:    ret i8* null
;
  ret i8* null
}

define internal i8* @dont_zap_me(i8 %v) {
; CHECK-LABEL: define {{[^@]+}}@dont_zap_me
; CHECK-SAME: (i8 [[V:%.*]])
; CHECK-NEXT:    [[I1:%.*]] = call i32 @external()
; CHECK-NEXT:    ret i8* null
;
  %i1 = call i32 @external()
  ret i8* null
}
