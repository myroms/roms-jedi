/*
 * (C) Copyright 2019-2021 UCAR.
 *
 * This software is licensed under the terms of the Apache Licence Version 2.0
 * which can be obtained at http://www.apache.org/licenses/LICENSE-2.0.
 */

#include "oops/runs/Dirac.h"
#include "oops/runs/Run.h"
#include "romsjedi/Traits.h"
//  #include "saber/oops/instantiateLocalizationFactory.h"

int main(int argc,  char ** argv) {
  oops::Run run(argc, argv);
  //  saber::instantiateLocalizationFactory<romsjedi::Traits>();
  oops::Dirac<romsjedi::Traits> dir;
  return run.execute(dir);
}
