# PSCryptoPatterns — module loader
# Dot-sources in dependency order (load order matters for PS classes)

$private = @(
    '01_ClassMechanics.ps1'
    '02_Inheritance.ps1'
    '03_InterfacePatterns.ps1'
    '04_AccessModifiers.ps1'
    '05_FactoryMethod.ps1'
    '06_AbstractFactory.ps1'
    '07_BuilderPattern.ps1'
    '08_ObjectPool.ps1'
    '09_Prototype.ps1'
    '10_CompositionVsInheritance.ps1'
    '11_MixinScriptblock.ps1'
    '12_GenericCollections.ps1'
    '13_TemplateMethod.ps1'
    '14_StateMachine.ps1'
    '15_CommandPattern.ps1'
    '16_NullObject.ps1'
    '17_EventsDelegates.ps1'
    '18_UpdateTypeData.ps1'
    '19_MethodOverloading.ps1'
    '20_StaticConstructors.ps1'
    '21_OperatorOverloading.ps1'
    '22_RecursiveTypes.ps1'
    '23_KeyRotation.ps1'
    '24_AlgorithmAgility.ps1'
    '25_ReplayPrevention.ps1'
    '26_SecureMemory.ps1'
    '27_CertChainValidation.ps1'
)

foreach ($file in $private) {
    . "$PSScriptRoot/$file"
}
