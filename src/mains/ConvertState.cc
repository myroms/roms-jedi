/*
 * (C) Copyright 2017-2025 UCAR
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "oops/runs/ConvertState.h"
#include "oops/runs/Run.h"

#include "romsjedi/Traits.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  oops::ConvertState<romsjedi::Traits> cs;
  return run.execute(cs);
}
