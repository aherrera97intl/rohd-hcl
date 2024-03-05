// Copyright (C) 2023 Intel Corporation
// SPDX-License-Identifier: BSD-3-Clause
//
// crc_generator.dart
// Implementation of CRC Generator.
//
// 2023 March 13
// Author: Andrey Herrera Solano <andrey.herrera.solano@intel.com>

import 'package:rohd/rohd.dart';
import 'package:rohd_hcl/src/exceptions.dart';

///[matrixMultiplyBits] uses two matrix [a] and [b] where
LogicArray matrixMultiplyBits(LogicArray a, LogicArray b) {
  assert(a.dimensions[1] == b.dimensions[0]);
  assert(a.elementWidth == b.elementWidth);
  final elementWidth = a.elementWidth;
  assert(elementWidth == 1);
  final c = LogicArray([a.dimensions[0], b.dimensions[1]], elementWidth);

  for (var aRow = 0; aRow < a.dimensions[0]; aRow++) {
    for (var bCol = 0; bCol < b.dimensions[1]; bCol++) {
      Logic dotProduct = Const(0);
      for (var i = 0; i < b.dimensions[0]; i++) {
        dotProduct ^=
            a.elements[aRow].elements[i] & b.elements[i].elements[bCol];
      }
      c.elements[aRow].elements[bCol] <= dotProduct;
    }
  }

  return c;
}

LogicArray addVectorBits(LogicArray a, LogicArray b) {
  assert(a.dimensions.length == 1);
  assert(b.dimensions.length == 1);
  assert(a.dimensions.first == b.dimensions.first);
  assert(a.elementWidth == b.elementWidth);
  final elementWidth = a.elementWidth;
  assert(elementWidth == 1);

  // we can use ^ for add since they are all 1-bit
  final c = LogicArray(a.dimensions, elementWidth);

  for (var i = 0; i < a.dimensions.first; i++) {
    c.elements[i] <= a.elements[i] ^ b.elements[i];
  }

  return c;
}

LogicArray generateMatrixWithPol(int dataWidth, List<Logic> polynomial) {
  var test = polynomial.swizzle();
  var matrix = LogicArray([dataWidth, dataWidth], 1, name: 'transitionMatrix');
  var column = 0;
  for (var row = 0; row < dataWidth; row++) {
    matrix.elements[row].elements[column] <= test[row + 1];
    print(matrix.elements[row].elements[column].value);
  }

  for (column = 1; column < dataWidth; column++) {
    for (var row = 0; row < dataWidth; row++)
      matrix.elements[row].elements[column] <=
          (row == column - 1 ? Const(LogicValue.one) : Const(LogicValue.zero));
  }
  return matrix;
}

///Function [matrixPowerBits] designed to multiply [matrix] using [power]
///with a [matrixResult] array to store result and multiply it with original
///matrix [matrix], then returning final result.
///Multiplications of [matrix] are done by [matrixPowerBits] and must contain
///only bits.
LogicArray matrixPowerBits(LogicArray matrix, int power) {
  var matrixResult = matrix;
  for (var x = 1; x < power; x++) {
    matrixResult = matrixMultiplyBits(matrixResult, matrix);
  }
  return matrixResult;
}

class MatrixModule2 extends Module {
  MatrixModule2(int dataWidth, List<Logic> polynomial) {
    final matrix = generateMatrixWithPol(dataWidth, polynomial);
    print2D(matrix);
    final intermediate = matrixPowerBits(matrix, dataWidth);
    print2D(intermediate);
    addOutputArray('intermediate', dimensions: [dataWidth, dataWidth]) <=
        intermediate;
    List<Logic> crcResult =
        List.generate(dataWidth, (i) => Logic(name: 'crcResult$i'));
    ;
    final vector = Logic(width: 6);
    List<Logic> test = List.generate(6, (i) => vector[i]);
    vector.put('0011');
    print(crcResult.swizzle().value);
  }
}

void print2D(LogicArray a) {
  print(a.elements
      .map((r) =>
          r.elements.map((c) => c.value.toString(includeWidth: false)).join(''))
      .join('\n'));
}

void main() async {
  const bitsWidth = 4;
  const width = 5;
  final vector = Logic(width: width);
  final polynomial = List.generate(width, (i) => vector[i]);
  //vector.put(bin('1111000000011'));
  vector.put(bin('11011'));

  final mod = MatrixModule2(bitsWidth, polynomial);
  await mod.build();
  //print(mod.generateSynth());
}
