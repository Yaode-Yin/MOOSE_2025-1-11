#use miug mius mm
[GlobalParams]
  displacements = 'disp_x disp_y'
  #temperature = T
  # use_displaced_mesh = true
[]

[Mesh]
  [gen]
    type = GeneratedMeshGenerator
    dim = 2
    nx = 1
    ny = 1
    xmin = 0
    ymin = 0 
    xmax = 1e-3
    ymax = 1e-3
  []
[]

[Variables]
  [c]
    order = FIRST
    family = LAGRANGE
  []
[]


[AuxVariables]
  [bounds_dummy]
    order = FIRST
    family = LAGRANGE
  []
  [disp_x]
    order = FIRST
    family = LAGRANGE
  []
  [disp_y]
    order = FIRST
    family = LAGRANGE
  []
  [T]
    order = FIRST
    family = LAGRANGE
  []
  [./grad_c_x]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [./grad_c_y]
    order = CONSTANT
    family = MONOMIAL
  [../]
  [positive_energy]
   order = CONSTANT
   family = MONOMIAL
  []
[]

[AuxKernels]
  [./grad_c_x_aux]
    type = VariableGradientComponent
    variable = grad_c_x
    component = x
    gradient_variable = c
  []
  [./grad_c_y_aux]
    type = VariableGradientComponent
    variable = grad_c_y
    component = y
    gradient_variable = c
  []
[]

[Kernels]
  [./ACBulk]
    type = AllenCahn
    variable = c
    f_name = F
  [../]

  [./ACInterface]
    type = ACInterface
    variable = c
    kappa_name = kappa_op
  [../]
[]



[Materials]
## temperature-dependent material properties
  [youngs_E]
    type = DerivativeParsedMaterial
    coupled_variables = T
    expression = '417e9 - 0.0525e9*(T-273)'
    property_name = youngs_E
    derivative_order = 2
  []
  [poisson]
    type = DerivativeParsedMaterial
    coupled_variables = T
    expression = '(417e9 - 0.0525e9*(T-273))/(2*(169e9 - 0.0229e9*(T-273)))-1'
    property_name = poisson
    derivative_order =2
  []  
  [gc_prop]
    type = DerivativeParsedMaterial
    coupled_variables = T
    expression = '((2775*exp(0.0000476*(T-273))/(T-273+1323)+0.084*300^0.5)*1e6)^2/(417e9 - 0.0525e9*(T-273))*(1-((417e9 - 0.0525e9*(T-273))/(2*(169e9 - 0.0229e9*(T-273)))-1)^2)'
    property_name = gc_prop
    derivative_order =2
  #  outputs = exodus
  []
  [pfbulkmat]
    type = GenericConstantMaterial
    prop_names = 'l c0 T0'
    prop_values = '1e-5 3.1415926 600'  
  []
  
  [Free_energy]
    type = DerivativeParsedMaterial
    material_property_names = 'l c0 gc_prop degradation'
    property_name = F
    coupled_variables = 'c positive_energy'
    expression = 'positive_energy * degradation + gc_prop * (2*c-c*c)/ (c0 * l)'
    constant_names       = 'eta'
    constant_expressions = '1e-6'
    outputs = exodus
  []
  [Free_energy_1]
    type = DerivativeParsedMaterial
 #   material_property_names = ' degradation'
    property_name = F_1
    coupled_variables = 'positive_energy'
    expression = 'positive_energy'
    outputs = exodus
  []
  
  [degradation]
    type = DerivativeParsedMaterial
    property_name = degradation
    material_property_names= 'l c0'
    coupled_variables = 'c T'
    expression = '((1-c)^2/((1-c)^2+(4 * (((2775*exp(0.0000476*(T-273))/(T-273+1323)+0.084*300^0.5)*1e6)^2/(417e9 - 0.0525e9*(T-273))*(1-((417e9 - 0.0525e9*(T-273))/(2*(169e9 - 0.0229e9*(T-273)))-1)^2)) * (417e9 - 0.0525e9*(T-273)) / (1-((417e9 - 0.0525e9*(T-273))/(2*(169e9 - 0.0229e9*(T-273)))-1)^2) / ((267-256*(1+5.8e9*exp(-0.018*(T-273)))^-0.5)*1e6)^2 / c0/ l)*c*(1-0.5*c))) *(1-eta)+eta'
    constant_names       = 'eta'
    constant_expressions = '1e-6'
    derivative_order = 3
    outputs = exodus
  []  
  
  [define_mobility]
    type = ParsedMaterial
    # material_property_names = 'gc_prop'
    property_name = L
    expression = '1.0'
  []
  [define_kappa]
    type = ParsedMaterial
    material_property_names = 'gc_prop l c0'
    property_name = kappa_op
    expression = '2* gc_prop * l /c0'
  []  
######  fracture energy 
  [local_fracture_energy]
    type = ParsedMaterial
    property_name = local_fracture_energy
    coupled_variables = 'c'
    material_property_names = 'gc_prop l c0'
    expression = 'gc_prop/c0/l*(2*c-c^2)'
    outputs = exodus
  []
  [nonlocal_fracture_energy]
    type = ParsedMaterial
    property_name = nonlocal_fracture_energy
    coupled_variables = 'grad_c_x grad_c_y'
    material_property_names = 'gc_prop l c0'
    expression = 'gc_prop/c0*l*(grad_c_x^2+grad_c_y^2)'
  [] 
  [fracture_energy]
    type = DerivativeSumMaterial
    coupled_variables = 'c grad_c_x grad_c_y'
    sum_materials = 'nonlocal_fracture_energy local_fracture_energy'
    property_name = fracture_energy
  []
[]

[Postprocessors]
  [./total_fracture_energy]
   type = ElementIntegralMaterialProperty
   mat_prop = fracture_energy
  [../]
[]

[Bounds]
  [irreversibility]
    type = VariableOldValueBounds
    variable = bounds_dummy
    bounded_variable = c
    bound_type = lower
  []
  [upper]
    type = ConstantBounds
    variable = bounds_dummy
   bounded_variable = c
    bound_type = upper
    bound_value = 1.0
  []
[]

[Executioner]
   type = Transient
   solve_type = NEWTON
   petsc_options_iname = '-pc_type  -snes_type'
   petsc_options_value = 'lu vinewtonrsls'
   nl_abs_tol = 1e-5
   nl_rel_tol = 1e-5
   
   start_time = 0.0  
   end_time = 5000e-9
   
   dt = 1e-4
  # dt = 5e-6
   dtmin= 1e-4
[]
[Outputs]
  exodus = true
  csv=true
  print_linear_residuals = false
 # interval = 1
[]
